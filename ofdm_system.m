function [data_out, data_valid] = ofdm_system(start, data_in)
%OFDM_SYSTEM  4-point BPSK OFDM transmitter + receiver (HDL Coder design)
%   MATLAB equivalent of the hand-written Verilog ofdm_system module.
%
%   Inputs : start      (logical)          - 1-cycle pulse, starts one OFDM symbol
%            data_in    (ufix4)            - 4 bits, data_in[3] -> X0 ... data_in[0] -> X3
%   Outputs: data_out   (ufix4)            - received bits
%            data_valid (logical)          - HIGH once data_out is ready (stays HIGH)
%
%   State machine (1 state per clock):
%     IDLE -> CP -> SAMPLE0 -> SAMPLE1 -> SAMPLE2 -> SAMPLE3 -> FFT -> DONE -> IDLE
%
%   BPSK mapping : bit 1 -> +1, bit 0 -> -1
%   4-pt IFFT    : x0 = X0+X1+X2+X3          x1 = (X0-X2) + j(X1-X3)
%                  x2 = X0-X1+X2-X3          x3 = (X0-X2) + j(X3-X1)
%   Cyclic prefix: CP = x3
%   4-pt FFT     : real parts only (enough for BPSK decision)
%#codegen

F = fimath('RoundingMethod','Floor','OverflowAction','Wrap', ...
           'ProductMode','FullPrecision','SumMode','FullPrecision');

% ---------------- state encoding (3-bit) ----------------------------------
IDLE    = uint8(0);
CP      = uint8(1);
SAMPLE0 = uint8(2);
SAMPLE1 = uint8(3);
SAMPLE2 = uint8(4);
SAMPLE3 = uint8(5);
FFT     = uint8(6);
DONE    = uint8(7);

% ---------------- registers (persistent = flip-flops) ---------------------
persistent state tx_re tx_im rx_re rx_im fft0 fft1 fft2 fft3 data_out_r data_valid_r
if isempty(state)
    state        = IDLE;
    tx_re        = fi(zeros(1,5), 1, 8, 0, F);   % tx[0] = CP, tx[1..4] = x0..x3
    tx_im        = fi(zeros(1,5), 1, 8, 0, F);
    rx_re        = fi(zeros(1,4), 1, 8, 0, F);   % CP not stored at receiver
    rx_im        = fi(zeros(1,4), 1, 8, 0, F);
    fft0         = fi(0, 1, 16, 0, F);
    fft1         = fi(0, 1, 16, 0, F);
    fft2         = fi(0, 1, 16, 0, F);
    fft3         = fi(0, 1, 16, 0, F);
    data_out_r   = fi(0, 0, 4, 0, F);
    data_valid_r = false;
end

% registered outputs (same as "output reg" in Verilog)
data_out   = data_out_r;
data_valid = data_valid_r;

% ---------------- main OFDM process ---------------------------------------
switch state

    % ==================== IDLE : BPSK + IFFT + CP =========================
    case IDLE
        if start
            % BPSK mapping
            X0 = bpsk(bitget(data_in, 4));
            X1 = bpsk(bitget(data_in, 3));
            X2 = bpsk(bitget(data_in, 2));
            X3 = bpsk(bitget(data_in, 1));

            % 4-point IFFT
            tx_re(2) = X0 + X1 + X2 + X3;      tx_im(2) = 0;         % x0
            tx_re(3) = X0 - X2;                tx_im(3) = X1 - X3;   % x1
            tx_re(4) = X0 - X1 + X2 - X3;      tx_im(4) = 0;         % x2
            tx_re(5) = X0 - X2;                tx_im(5) = X3 - X1;   % x3

            % Cyclic prefix = x3
            tx_re(1) = X0 - X2;                tx_im(1) = X3 - X1;

            data_valid_r = false;
            state        = CP;
        end

    % ==================== CP : transmitted, discarded by RX ===============
    case CP
        state = SAMPLE0;

    % ==================== noiseless channel, one sample per clock =========
    case SAMPLE0
        rx_re(1) = tx_re(2);  rx_im(1) = tx_im(2);
        state    = SAMPLE1;

    case SAMPLE1
        rx_re(2) = tx_re(3);  rx_im(2) = tx_im(3);
        state    = SAMPLE2;

    case SAMPLE2
        rx_re(3) = tx_re(4);  rx_im(3) = tx_im(4);
        state    = SAMPLE3;

    case SAMPLE3
        rx_re(4) = tx_re(5);  rx_im(4) = tx_im(5);
        state    = FFT;

    % ==================== RX 4-point FFT (real parts) =====================
    case FFT
        fft0(:) = rx_re(1) + rx_re(2) + rx_re(3) + rx_re(4);
        fft1(:) = rx_re(1) + rx_im(2) - rx_re(3) - rx_im(4);
        fft2(:) = rx_re(1) - rx_re(2) + rx_re(3) - rx_re(4);
        fft3(:) = rx_re(1) - rx_im(2) - rx_re(3) + rx_im(4);
        state   = DONE;

    % ==================== BPSK demodulation ===============================
    case DONE
        d3 = fi(fft0 > 0, 0, 1, 0);
        d2 = fi(fft1 > 0, 0, 1, 0);
        d1 = fi(fft2 > 0, 0, 1, 0);
        d0 = fi(fft3 > 0, 0, 1, 0);
        data_out_r(:) = bitconcat(d3, d2, d1, d0);
        data_valid_r  = true;
        state         = IDLE;

    otherwise
        state = IDLE;
end
end

%==========================================================================
function s = bpsk(b)
% BPSK mapper: 1 -> +1, 0 -> -1
F = fimath('RoundingMethod','Floor','OverflowAction','Wrap', ...
           'ProductMode','FullPrecision','SumMode','FullPrecision');
if b
    s = fi( 1, 1, 8, 0, F);
else
    s = fi(-1, 1, 8, 0, F);
end
end