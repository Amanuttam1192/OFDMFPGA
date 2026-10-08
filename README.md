Scripts for CodeGen:
Run these in Command line after once running the tb file:

hdlcfg = coder.config('hdl');
hdlcfg.TargetLanguage = 'Verilog';
hdlcfg.TestBenchName = 'tb_ofdm_system_hdl';
hdlcfg.GenerateHDLTestBench = true;
hdlcfg.ResetType = 'Synchronous';
hdlcfg.MinimizeClockEnables = true;

clear ofdm_system
codegen -config hdlcfg ofdm_system -args {false, fi(0,0,4,0)} -report
