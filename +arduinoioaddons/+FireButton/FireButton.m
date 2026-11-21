classdef FireButton < matlabshared.addon.LibraryBase
    % Collect short button presses between MATLAB input reads.
    properties (Access = protected, Constant)
        LibraryName = 'FireButton/FireButton'
        DependentLibraries = {}
        LibraryHeaderFiles = {}
        CppHeaderFile = fullfile(arduinoio.FilePath(mfilename('fullpath')), 'src', 'FireButton.h')
        CppClassName = 'FireButton'
    end

    properties (Access = private, Constant)
        Configure = 1
        SetEnabled = 2
        ReadPresses = 3
    end

    methods
        function obj = FireButton(parent, pin, pressedValue)
            % The caller configures the pin's input mode before creating the add-on.
            obj.Parent = parent;
            terminal = getTerminalsFromPins(parent, pin);
            sendCommand(obj, obj.LibraryName, obj.Configure, uint8([terminal, pressedValue]));
        end

        function enableCapture(obj, enabled)
            sendCommand(obj, obj.LibraryName, obj.SetEnabled, uint8(enabled));
        end

        function [count, level] = takePresses(obj)
            response = sendCommand(obj, obj.LibraryName, obj.ReadPresses, uint8([]));
            count = double(response(1));
            level = double(response(2));
        end
    end
end
