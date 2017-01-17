function tf = hciUtilHaveNmtButNoHardwareDebugMode

persistent hasWarned

tf = true; % True for working without the hardware but have NMT (and want to check with the NMT software).

if ~ispc
    % MAC of Linux
    if ~tf
        warning('hci:NoHardWareDebugWithNMT','hciUtilHaveNmtButNoHardware is set to return false. This means that stimuli would be sent to the hardware BUT you are not on a PC so obviously you can''t be using the hardware.');
        tf = true;
    end
else
%     switch getenv('name')
%         case 'lab'
%             if tf
%                 warn('hci:NoHarWareDebug','hciUtilNoHardwareDebugMode is set to return true. This means that stimuli would not be sent to the hardware BUT you are on a PC with the account name lab so I am going to assume you want to use the hardware.');
%                 tf = false;
%             end
%         otherwise
%             % ?
%     end
end

if isempty(hasWarned) && tf
    % First time run today. Warn
    
    warning('hci:NoHardWareDebugWithNMT','hciUtilHaveNmtButNoHardware is set to return true. This means that stimuli are not being sent to the hardware BUT the NMT will be used to generate sequences. Edit hciUtilHaveNmtButNoHardware to return false to enable hardware streaming');
    
    hasWarned = true;
end

