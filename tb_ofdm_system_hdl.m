%% tb_ofdm_system.m  - MATLAB testbench for ofdm_system.m
%  Same tests as the Verilog testbench: 1011, 1100, 0101, 1111.
%  One call of ofdm_system = one clock cycle (10 ns at 100 MHz).
clear ofdm_system                        % reset all registers

tests     = {'1011', '1100', '0101', '1111'};
cycle     = 0;
prevValid = false;
nPass     = 0;
dinZero   = fi(0, 0, 4, 0);

% ---------------- reset + wait (Verilog: #20 reset, #20 idle) -------------
for k = 1:4
    [dout, dv] = ofdm_system(false, dinZero);
    cycle = cycle + 1;
end

% ---------------- tests ---------------------------------------------------
for t = 1:numel(tests)
    din = fi(bin2dec(tests{t}), 0, 4, 0);

    % start pulse for 1 clock (Verilog: start = 1; #10; start = 0;)
    [dout, dv] = ofdm_system(true, din);
    cycle = cycle + 1;

    % wait 10 clocks for processing (Verilog: #100)
    for k = 1:10
        [dout, dv] = ofdm_system(false, din);
        cycle = cycle + 1;
        if dv && ~prevValid
            fprintf('TIME = %d ns : RECEIVED DATA = %s\n', cycle*10, dec2bin(double(dout), 4));
        end
        prevValid = dv;
    end

    rx = dec2bin(double(dout), 4);
    ok = strcmp(rx, tests{t}) && dv;
    nPass = nPass + ok;

    fprintf('-----------------------------------------\n');
    fprintf('TEST %d\n', t);
    fprintf('TRANSMITTED : %s\n', tests{t});
    fprintf('RECEIVED    : %s\n', rx);
    fprintf('VALID       : %d\n', dv);
    if ok, fprintf('RESULT      : PASS\n'); else, fprintf('RESULT      : FAIL\n'); end
    fprintf('-----------------------------------------\n');

    % idle gap between tests (Verilog: #20)
    for k = 1:2
        [dout, dv] = ofdm_system(false, din);
        cycle = cycle + 1;
        prevValid = dv;
    end
end

fprintf('\n%d / %d tests passed\n', nPass, numel(tests));