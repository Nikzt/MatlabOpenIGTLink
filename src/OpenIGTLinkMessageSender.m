function openIGTMessageSender = OpenIGTLinkMessageSender(sock)
    global socket;
    socket = sock;
    openIGTMessageSender.WriteOpenIGTLinkStringMessage = @WriteOpenIGTLinkStringMessage;
    openIGTMessageSender.Write1DFloatArrayMessage = @Write1DFloatArrayMessage;
    openIGTMessageSender.igtlSendTransformMessage = @igtlSendTransformMessage;
end

function result=WriteOpenIGTLinkStringMessage(deviceName, msgString)
    msg.dataTypeName='STRING';
    msg.deviceName=deviceName;
    msg.timestamp=igtlTimestampNow();
    msgString=[uint8(msgString) uint8(0)]; % Convert string to uint8 vector and add terminator character
    msg.body=[convertFromUint16ToUint8Vector(3),convertFromUint16ToUint8Vector(length(msgString)),msgString];
    result=WriteOpenIGTLinkMessage(msg);
end

function result=Write1DFloatArrayMessage(deviceName, data)
    msg.dataTypeName='NDARRAY';
    msg.deviceName=deviceName;
    msg.timestamp=igtlTimestampNow();
    
    msg.body=[uint8(10), uint8(1), convertFromUint16ToUint8Vector(length(data))];
    for i=1:length(data)
        msg.body=[ msg.body, convertFromFloat32ToUint8Vector(data(i))];
    end
    result=WriteOpenIGTLinkMessage(msg);
end

function result=igtlSendTransformMessage(deviceName, transform, timestamp)
    msg.dataTypeName='TRANSFORM';
    msg.deviceName=deviceName;
    msg.timestamp=igtlTimestampNow();
    msg.timestamp=timestamp;
    % version number
    % note that it is an unsigned short value, but small positive signed and unsigned numbers are represented the same way, so we can use writeShort
    msg.body = [];
    for i=1:4
        for j=1:3
            msg.body=[ msg.body, convertFromFloat32ToUint8Vector(transform(j,i))];
        end
    end
    result=WriteOpenIGTLinkMessage(msg);
end


% Returns 1 if successful, 0 if failed
function result=WriteOpenIGTLinkMessage(msg)
    global socket;
    import java.net.Socket
    import java.io.*
    import java.net.ServerSocket
    % Add constant fields values
    msg.versionNumber=1;
    msg.bodySize=length(msg.body);
    crc=0;
    for k=1:length(msg.body)
        crc=igtlComputeCrc(msg.body(k),crc);
        disp(crc)
    end
    msg.bodyCrc=crc;
    % Pack message
    data=[];
    data=[data, convertFromUint16ToUint8Vector(msg.versionNumber)];
    data=[data, padString(msg.dataTypeName,12)];
    data=[data, padString(msg.deviceName,20)];
    data=[data, convertFromInt64ToUint8Vector(msg.timestamp)];
    data=[data, convertFromInt64ToUint8Vector(msg.bodySize)];
    data=[data, convertFromUint64ToUint8Vector(msg.bodyCrc)];
    %data=[data, typecast(msg.body, 'uint8')];
    data=[data, uint8(msg.body)];
    result=1;
    try
        DataOutputStream(socket.outputStream).write(uint8(data),0,length(data));
    catch ME
        disp(ME.message)
        result=0;
    end
    try
        DataOutputStream(socket.outputStream).flush;
    catch ME
        disp(ME.message)
        result=0;
    end
    if (result==0)
      disp('Sending OpenIGTLink message failed');
    end
end

function result=convertFromFloat32ToUint8Vector(float32Val)
    hex = num2hex(single(float32Val));
    
    result=zeros(1,4,'uint8');
    result(1)=uint8(hex2dec(hex(1:2)));
    result(2)=uint8(hex2dec(hex(3:4)));
    result(3)=uint8(hex2dec(hex(5:6)));
    result(4)=uint8(hex2dec(hex(7:8)));
end

function selectedByte=getNthByte(multibyte, n)
  selectedByte=uint8(mod(floor(multibyte/256^n),256));
end

function result=convertFromUint16ToUint8Vector(uint16Value)
  result=[getNthByte(uint16Value,1) getNthByte(uint16Value,0)];
end

function result=convertFromInt32ToUint8Vector(int32Value)
  result=zeros(1,4,'uint8');
  result(1)=getNthByte(int32Value,3);
  result(2)=getNthByte(int32Value,2);
  result(3)=getNthByte(int32Value,1);
  result(4)=getNthByte(int32Value,0);
end

function result=convertFromInt64ToUint8Vector(int64Value)
  result=zeros(1,8,'uint8');
  result(1)=getNthByte(int64Value,7);
  result(2)=getNthByte(int64Value,6);
  result(3)=getNthByte(int64Value,5);
  result(4)=getNthByte(int64Value,4);
  result(5)=getNthByte(int64Value,3);
  result(6)=getNthByte(int64Value,2);
  result(7)=getNthByte(int64Value,1);
  result(8)=getNthByte(int64Value,0);
end

function result=convertFromUint64ToUint8Vector(uint64Value)
  result = typecast(uint64(uint64Value),'uint8');
end

function paddedStr=padString(str,strLen)
  paddedStr=str(1:min(length(str),strLen));
  paddingLength=strLen-length(paddedStr);
  if (paddingLength>0)
      paddedStr=[paddedStr,zeros(1,paddingLength,'uint8')];
  end
end

function timestamp = igtlTimestampNow()
% igtlTimestampNow  Time elapsed since 00:00:00 January 1, 1970, UTC, in seconds
%
%   timestamp = igtlTimestampNow()
%
%  Example:
%
%   igtlConnection = igtlConnect('127.0.0.1',18944);
%   transform.name = 'NeedleToTracker';
%   transform.matrix = [ 1 0 0 10; 0 1 0 -5; 0 0 1 20; 0 0 0 1 ];
%   transform.timestamp = igtlTimestampNow();
%   igtlSendTransform(igtlConnection, transform);
%   igtlDisconnect(igtlConnection);
%

timestamp = java.lang.System.currentTimeMillis/1000;
end
