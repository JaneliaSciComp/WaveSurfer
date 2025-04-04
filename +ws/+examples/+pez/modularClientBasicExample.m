function modularClientBasicExample(port)
% modularClientBasicExample: demonstrates basic use of the
% ModularClient class.
%
%  * Find serial port of modular device connected with a USB cable.
%    Windows:
%      Use command getAvailableComPorts()
%      Or use 'Device Manager' and look under 'Ports'.
%      Typically 'COM3' or higher.
%    Mac OS X:
%      Typically something like '/dev/tty.usbmodem'
%    Linux:
%      Typically something like '/dev/ttyACM0'
%
% Usage: (replace 'COM5' with the serial port of your device)
%
% getAvailableComPorts()
% modularClientBasicExample('COM5')
%

    % Create the Modular client object, open serial
    % connection and display device id.
    fprintf('Opening Modular client...\n');
    dev = ws.examples.pez.ModularClient(port);
    dev.open();
    fprintf('Modular Device ID:');
    dev.getDeviceId()

    % Pause for a little bit for added dramma
    pause(1.0)

    % Print dynamic methods
    dev.getMethods()
    fprintf('\n');

    % Clean up -
    dev.close();
    delete(dev);
    fprintf('Closed client. Goodbye!\n');
end
