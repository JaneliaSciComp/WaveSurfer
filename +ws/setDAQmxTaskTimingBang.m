function setDAQmxTaskTimingBang(taskHandle, clockTiming, expectedScanCount, sampleRate)
    switch clockTiming ,
        case 'DAQmx_Val_FiniteSamps'
            ws.ni('DAQmxCfgSampClkTiming', ...
                  taskHandle, ...
                  '', ...
                  sampleRate, ...
                  'DAQmx_Val_Rising', ...
                  'DAQmx_Val_FiniteSamps', ...
                  expectedScanCount) ;
              % we validated the sample rate when we created
              % the input task, so should be ok, but check
              % anyway
              if ws.ni('DAQmxGetSampClkRate', taskHandle)~=sampleRate ,
                  error('The DABS task sample rate is not equal to the desired sampling rate') ;
              end  
        case 'DAQmx_Val_ContSamps'
            if isinf(expectedScanCount) ,
                bufferSize = sampleRate ;  % Default to 1 second of data as the buffer.
            else
                bufferSize = expectedScanCount ;
            end
            ws.ni('DAQmxCfgSampClkTiming', ...
                  taskHandle, ...
                  '', ...
                  sampleRate, ...
                  'DAQmx_Val_Rising', ...
                  'DAQmx_Val_ContSamps', ...
                  2*bufferSize) ;
              % we validated the sample rate when we created
              % the input task, so should be ok, but check
              % anyway
              if ws.ni('DAQmxGetSampClkRate', taskHandle) ~= sampleRate ,
                  error('The DABS task sample rate is not equal to the desired sampling rate');
              end  
        otherwise
            error('ws:finiteacquisition:unknownclocktiming', 'Unexpected clock timing mode.');
    end
end          
