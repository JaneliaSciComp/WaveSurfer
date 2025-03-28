% ModularClient - This is the Matlab modular device client library for
%    communicating with and calling remote methods on modular device
%    servers.matlab serial interface for controlling and
%
% Public properties
% ------------------
%
%   * debug = debug flag, turns on debug messages if true.
%
%   (Dependent)
%   * isOpen    = true is serial connection to device is open, false otherwire
%   * methodIds = structure of method identification numbers retrieved from device.
%
%
% Note, in what follows 'dev' is assumed to be an instance of the ModularClient class.
% dev = ModularClient(portName)
%
% Regular (public) class methods
% -----------------------------
%
%   * open - opens serial connection to device
%     Usage: dev.open()
%
%   * close - closes serial connection to device
%     Usage: dev.close()
%
%   * delete - deletes instance of client object.
%     Usage: dev.delete() or delete(dev)
%
%   * getMethods - prints the names of all dynamically generated class
%     methods. Note, the client must be opened for this method to work.
%     Usage: dev.getMethods()
%
%   * callGetResult
%
%   * convertToJson
%
%   * sendJsonRequest
%
% Notes:
%
%  * Find serial port of modular device connected with a USB cable.
%    When the modular device is Arduino-based, you can use the
%    Arduino environment to help find port. Read more details
%    here: http://arduino.cc/en/Guide/HomePage
%    Windows:
%      Use command getAvailableComPorts()
%      Or use 'Device Manager' and look under 'Ports'.
%      Typically 'COM3' or higher.
%    Mac OS X:
%      Typically something like '/dev/tty.usbmodem'
%    Linux:
%      Typically something like '/dev/ttyACM0'
%
%
% Typical Usage:
%
%   % Linux and Mac OS X
%   ls /dev/tty*
%   serial_port = '/dev/ttyACM0'            % example Linux serial port
%   serial_port = '/dev/tty.usbmodem262471' % example Mac OS X serial port
%                                           % Windows
%   getAvailableComPorts()
%   ans =
%   'COM1'
%   'COM4'
%   serial_port = 'COM4'                    % example Windows serial port
%                                           %
%   dev = ModularClient(serial_port)        % creates a client object
%   dev.open()                              % opens a serial connection to the device
%   device_id = dev.getDeviceId()           % get device id
%   dev.getMethods()                        % get device methods
%   dev.serialNumber()                      % get device serial number
%   dev.serialNumber('getValue')            % get device serial number alternative
%   dev.serialNumber('setValue',1)          % integers are automatically cast to int32
%   dev.close()                             % close serial connection
%   delete(dev)                             % deletes the client
%
%   debug = true
%   dev = ModularClient(serial_port,debug)  % creates a client object with debugging
%
% This class is copied from
% https://github.com/janelia-matlab/modular_client_matlab 
% at commit 502b3334e9c9409485dfadb062fbe1296f141485, and was written by Peter Polidoro 
% at HHMI Janelia.


classdef ModularClient < handle

    properties
        dev = [];
        debug  = false;
    end

    properties (Access=private)
        methodIdStruct = [];
    end

    properties (Constant, Access=private)

        % Serial communication parameters.
        baudrate = 115200;
        databits = 8;
        stopbits = 1;
        timeout = 1.0;
        terminator = 'LF';
        resetDelay = 2.0;
        inputBufferSize = 8192;
        waitPauseDt = 0.25;
        powerOnDelay = 1.5;

        % Method ids for basic methods.
        methodIdGetMethods = 0;

    end


    properties (Dependent)
        isOpen;
        methodIds;
    end

    methods

        function obj = ModularClient(port,debug)
        % ModularClient - class constructor.
            obj.dev = serial( ...
                port, ...
                'baudrate', obj.baudrate, ...
                'databits', obj.databits, ...
                'stopbits', obj.stopbits, ...
                'timeout', obj.timeout, ...
                'terminator', obj.terminator,  ...
                'inputbuffersize', obj.inputBufferSize ...
                );
            if exist('debug','var')
                obj.debug = debug;
            end

        end

        function open(obj)
        % Open - opens a serial connection to the device.
            if obj.isOpen == false
                fopen(obj.dev);
                pause(obj.resetDelay);
                obj.createMethodIdStruct();
            end
        end

        function close(obj)
        % Close - closes the connection to the device.
            if obj.isOpen == true
                fclose(obj.dev);
            end
        end

        function delete(obj)
        % Delete - deletes the object.
            if obj.isOpen
                obj.close();
            end
            delete(obj.dev);
        end

        function isOpen = get.isOpen(obj)
        % get.isOpen - returns true/false depending on whether the connection
        % to the device is open.
            status = get(obj.dev,'status');
            if strcmpi(status,'open')
                isOpen = true;
            else
                isOpen = false;
            end
        end

        function getMethods(obj)
        % getMethods - prints all dynamically generated class methods.
            methodIdNames = fieldnames(obj.methodIdStruct);
            fprintf('\n');
            fprintf('Modular Device Methods\n');
            fprintf('---------------------\n');
            for i = 1:length(methodIdNames)
                fprintf('%s\n',methodIdNames{i});
            end
        end

        function result = callGetResult(obj,method,varargin)
            result = obj.sendRequestGetResult(method,varargin{:});
        end

        function call(obj,method,varargin)
            obj.callGetResult(method,varargin{:});
        end

        function json = convertToJson(obj,matlabToConvert)
            json = jsonencode(matlabToConvert);
            json = strtrim(json);
        end

        function result = sendJsonRequest(obj,request)
            if obj.isOpen
                requestCell = jsondecode(request);
                method = requestCell{1};
                requestJson = obj.convertToJson(requestCell);
                fprintf(obj.dev,requestJson);
                result = obj.handleResponse(method);
            else
                ME = MException( ...
                    'ModularClient:ClientNotOpen', ...
                    'connection must be open to send request to server' ...
                    );
                throw(ME);
            end
        end

        function methodIds = get.methodIds(obj)
        % get.methodIds - returns the structure of method Ids.
            methodIds = obj.methodIdStruct;
        end

        function varargout = subsref(obj,S)
        % subsref - overloaded subsref function to enable dynamic generation of
        % class methods from the methodIdStruct structure.
            val = [];
            if obj.isDynamicMethod(S)
                val = obj.dynamicMethodFcn(S);
                varargout = {val};
            else
                if nargout == 0
                    builtin('subsref',obj,S);
                else
                    val = builtin('subsref',obj,S);
                end
                if ~isempty(val)
                    varargout = {val};
                end
            end
        end

    end

    methods (Access=private)

        function result = handleResponse(obj,requestId)
            if obj.isOpen
                % Get response as json string and parse
                response = fscanf(obj.dev,'%c');
                if obj.debug
                    fprintf('response: ');
                    fprintf('%c',response);
                    fprintf('\n');
                end

                try
                    responseStruct = jsondecode(response);
                catch ME
                    causeME = MException( ...
                        'ModularClient:unableToParseJSON', ...
                        'Unable to parse server response' ...
                        );
                    ME = addCause(ME, causeME);
                    rethrow(ME);
                end

                % Check the returned id
                try
                    responseId = responseStruct.id;
                    responseStruct = rmfield(responseStruct,'id');
                catch ME
                    causeME = MException( ...
                        'ModularClient:MissingId', ...
                        'server response does not contain id member' ...
                        );
                    ME = addCause(ME, causeME);
                    rethrow(ME);
                end

                switch class(requestId)
                  case 'double'
                    if responseId ~= requestId
                        msg = sprintf( ...
                            'response id: %d does not match request id: %d', ...
                            responseId, ...
                            requestId ...
                            );
                        ME = MException('ModularClient:idDoesNotMatch', msg);
                        throw(ME);
                    end
                  case 'char'
                    if ~strcmp(responseId,requestId)
                        msg = sprintf( ...
                            'response id: %s does not match request id: %s', ...
                            responseId, ...
                            requestId ...
                            );
                        ME = MException('ModularClient:idDoesNotMatch', msg);
                        throw(ME);
                    end
                  otherwise
                    errMsg = sprintf('unknown requestId type, %s', class(requestId));
                    ME = MException('ModularClient:UnknownType', errMsg);
                    throw(ME);
                end

                % Check if there is a response error
                foundResponseError = false;
                try
                    responseError = responseStruct.error;
                    responseStruct = rmfield(responseStruct,'error');
                    try
                        message = responseError.message;
                    catch ME
                        message = '';
                    end
                    try
                        data = responseError.data;
                    catch ME
                        data = '';
                    end
                    try
                        code = responseError.code;
                    catch ME
                        code = '';
                    end
                    msg = sprintf( ...
                        '(from server) message: %s, data: %s, code: %s', ...
                        message, ...
                        data, ...
                        num2str(code) ...
                        );
                    foundResponseError = true;
                catch ME
                end

                if foundResponseError
                    ME = MException('ModularClient:Error', msg);
                    throw(ME);
                end

                % Find result
                try
                    result = responseStruct.result;
                catch ME
                    causeME = MException( ...
                        'ModularClient:MissingResult', ...
                        'server response does not contain result member' ...
                        );
                    ME = addCause(ME, causeME);
                    rethrow(ME);
                end

            else
                ME = MException( ...
                    'ModularClient:ClientNotOpen', ...
                    'connection must be open to send request to server' ...
                    );
                throw(ME);
            end
        end

        function result = sendRequestGetResult(obj,method,varargin)
        % sendRequestGetResult - sends a request to the server and reads the server's response.
        % The server responds to all requests with a serialized json string.
        % This string is parsed into a Matlab structure.
            if obj.isOpen

                % Send request to device
                request = obj.createRequest(method,varargin{:});
                if obj.debug
                    fprintf('request: ');
                    fprintf('%c',request);
                    fprintf('\n');
                end
                fprintf(obj.dev,request);
                result = obj.handleResponse(method);
            else
                ME = MException( ...
                    'ModularClient:ClientNotOpen', ...
                    'connection must be open to send request to server' ...
                    );
                throw(ME);
            end
        end

    end

    methods (Access=private)

        function request = createRequest(obj,method,varargin)
        % createRequest - create a request for sending to the device given
        % the method and a cell array of the request arguments.
            switch class(method)
              case 'double'
                request = sprintf('[%d',int32(method));
              case 'char'
                request = sprintf('[%s',method);
              otherwise
                errMsg = sprintf('unknown method type, %s', class(method));
                ME = MException('ModularClient:UnknownType', errMsg);
                throw(ME);
            end
            for i=1:length(varargin)
                arg = varargin{i};
                switch class(arg)
                  case 'double'
                    if length(arg) == 1
                        if floor(arg) ~= ceil(arg)
                            request = sprintf('%s, %f', request, arg);
                        else
                            request = sprintf('%s, %d', request, int32(arg));
                        end
                    else
                        json = obj.convertToJson(arg);
                        request = sprintf('%s, %s', request, json);
                    end
                  otherwise
                    json = obj.convertToJson(arg);
                    request = sprintf('%s, %s', request, json);
                end
            end
            request = sprintf('%s]',request);
        end

        function flag = isDynamicMethod(obj,S)
        % isDynamicMethod - used in the subsred function to determine whether
        % or not the method is dynamically generated. This is determined by
        % whether or not the name of the method given method is also the name
        % of a field in the methodIdStruct.
        %
        % Arguments:
        %  S = 'type' + 'subs' stucture passed to subsref function
            flag = false;
            if ~isempty(obj.methodIdStruct)
                if S(1).type == '.' & isfield(obj.methodIdStruct,S(1).subs)
                    flag= true;
                end
            end
        end

        function result = dynamicMethodFcn(obj,S)
        % dynamicMethodFcn - implements the dynamically generated class methods.

        % Get method name, method args and method id number
            methodName = S(1).subs;
            try
                requestArgs = S(2).subs;
            catch
                requestArgs = {};
            end
            methodId = obj.methodIdStruct.(methodName);

            % Convert method arguments from structure if required
            %if length(requestArgs) == 1 && strcmp(class(requestArgs{1}), 'struct')
            %    requestArgs = obj.convertArgStructToCell(requestArgs{1});
            %end

            % Send method and get responseStruct
            result = obj.sendRequestGetResult(methodId,requestArgs{:});
        end

        function createMethodIdStruct(obj)
        % createMethodIdStruct - gets structure of method Ids from
        % device.
            obj.methodIdStruct = obj.sendRequestGetResult(obj.methodIdGetMethods);
        end

    end
end

% Utility functions
% -----------------------------------------------------------------------------
function flag = isCellEqual(cellArray1, cellArray2)
% Tests whether or not two cell arrays of strings are eqaul.
% Returns false if both cell array don't consist entirely of strings
    flag = true;
    for i = 1:length(cellArray1)
        string = cellArray1{i};
        if ~isInCell(string,cellArray2)
            flag = false;
        end
    end
end


function flag = isInCell(string, cellArray)
% Test whether or not the given string is in the given cellArray.
    flag = false;
    if strcmp(class(string), 'char')
        for i = 1:length(cellArray)
            if strcmp(class(cellArray{i}),'char') && strcmp(cellArray{i}, string)
                flag = true;
                break;
            end
        end
    end
end
