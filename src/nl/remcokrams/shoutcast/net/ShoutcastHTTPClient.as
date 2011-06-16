package nl.remcokrams.shoutcast.net
{
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.net.Socket;
	import flash.net.URLRequest;
	import flash.net.URLRequestHeader;
	import flash.net.URLVariables;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	import flash.utils.IDataInput;
	import flash.utils.clearTimeout;
	import flash.utils.setTimeout;
	
	
	/**
	 *
	 * Author: remcokrams<br>
	 * Date: May 10, 2011
	 *
	 **/
	
	public class ShoutcastHTTPClient implements IDataInput
	{
		public static const MODE_PARSE_STATUS:int  = 1;
		public static const MODE_PARSE_HEADERS:int = 2;
		public static const MODE_DATA:int 		   = 3;
		
		public static const HTTP_VERSION:String = "1.1";
		public static const CRLF:String 		= "\r\n";
		public static const LF:String 			= "\n";
		public static const RESPONSE_HTTP_STATUS_MATCH:RegExp  = /HTTP\/[0-9]\.[0-9]\s(?P<status>[0-9]{3})\s[A-Za-z\s]+\r\n/g;
		public static const RESPONSE_HEADER_MATCH:RegExp 	   = /(?P<name>[^:]+):[\s]*(?P<value>.+?)\r\n/g;
		public static const RESPONSE_ICY_STATUS_MATCH:RegExp   = /ICY (?P<status>[0-9]{3}) [A-Za-z\s]+\r\n/g;
		
		protected var _request:HTTPRequest;
		protected var _socket:Socket;
		protected var _mode:int;
		protected var _status:int;
		protected var _headers:Vector.<URLRequestHeader>;
		protected var _responseData:String = "";
		protected var _lastFoundIndex:int;
		protected var _progressCallback:Function;
		protected var _reconnectTimeout:int;
		protected var _reconnectMode:Boolean;
		
		protected var _contentLength:int;
		protected var _loaded:int;
		
		public var responseCallback:Function = function (status:int, headers:Vector.<URLRequestHeader>):void {};
		public var errorCallback:Function 	 = function (status:int):void {};
		
		public function ShoutcastHTTPClient()
		{
			super();
			
			_socket = new Socket();
			_socket.endian = Endian.BIG_ENDIAN;
			_socket.addEventListener(Event.CONNECT, onSocketConnect);
			_socket.addEventListener(ProgressEvent.SOCKET_DATA, onSocketData);
			_socket.addEventListener(IOErrorEvent.IO_ERROR, onSocketError);
			_socket.addEventListener(Event.CLOSE, onSocketError);
		}
		
		public function get status():int {
			return _status;
		}
		
		public function get headers():Vector.<URLRequestHeader> {
			return _headers;
		}
		
		public function set progressCallback(value:Function):void {
			_progressCallback = value;
			
			if(_progressCallback != null)
				_socket.addEventListener(ProgressEvent.SOCKET_DATA, onSocketData);
			else if(_progressCallback == null && _mode == MODE_DATA)
				_socket.removeEventListener(ProgressEvent.SOCKET_DATA, onSocketData);
		}
		
		public function get progressCallback():Function {
			return _progressCallback;
		} 
		
		public function get bytesAvailable():uint
		{
			return _socket.bytesAvailable;
		}
		
		public function get endian():String
		{
			return _socket.endian;
		}
		
		public function set endian(type:String):void
		{
			_socket.endian = endian;
		}
		
		public function get objectEncoding():uint
		{
			return _socket.objectEncoding;
		}
		
		public function set objectEncoding(version:uint):void
		{
			_socket.objectEncoding = version;
		}
		
		public function readBoolean():Boolean
		{
			return _socket.readBoolean();
		}
		
		public function readByte():int
		{
			return _socket.readByte();
		}
		
		public function readBytes(bytes:ByteArray, offset:uint=0, length:uint=0):void
		{
			_socket.readBytes(bytes, offset, length);
		}
		
		public function readDouble():Number
		{
			return _socket.readDouble();
		}
		
		public function readFloat():Number
		{
			return _socket.readFloat();
		}
		
		public function readInt():int
		{
			return _socket.readInt();
		}
		
		public function readMultiByte(length:uint, charSet:String):String
		{
			return _socket.readMultiByte(length, charSet);
		}
		
		public function readObject():*
		{
			return _socket.readObject();
		}
		
		public function readShort():int
		{
			return _socket.readShort();
		}
		
		public function readUTF():String
		{
			return _socket.readUTF();
		}
		
		public function readUTFBytes(length:uint):String
		{
			return _socket.readUTFBytes(length);
		}
		
		public function readUnsignedByte():uint
		{
			return _socket.readUnsignedByte();
		}
		
		public function readUnsignedInt():uint
		{
			return _socket.readUnsignedInt();
		}
		
		public function readUnsignedShort():uint
		{
			return _socket.readUnsignedShort();
		}
		
		public function close():void {
			if(_socket.connected)
				_socket.close();
		}
		
		public function connect( request:URLRequest ):void {
			_reconnectMode = false;
			clearTimeout(_reconnectTimeout);
			_responseData = "";
			
			_request = new HTTPRequest( request );
			_mode = MODE_PARSE_STATUS;
			_headers = new Vector.<URLRequestHeader>();
			_lastFoundIndex = 0;
			_socket.addEventListener(ProgressEvent.SOCKET_DATA, onSocketData);
			_socket.connect(_request.host, _request.port);
		}
		
		public function startAutoReconnect():void {
			_reconnectMode = true;
			reconnect();
		}
		
		protected function planNextReconnect():void {
			_reconnectTimeout = setTimeout(reconnect, 2000);
		}
		
		protected function reconnect():void {
			_mode = MODE_PARSE_STATUS;
			_responseData = "";
			_headers = new Vector.<URLRequestHeader>();
			_lastFoundIndex = 0;
			_socket.addEventListener(ProgressEvent.SOCKET_DATA, onSocketData);
			_socket.connect(_request.host, _request.port);
		}
		
		protected function onSocketConnect(e:Event):void {
			var lines:Vector.<String> = new Vector.<String>();
			
			//request file
			lines.push( _request.method.toUpperCase() + " " + _request.path + " HTTP/" + HTTP_VERSION);
			
			//request headers
			for each(var header:URLRequestHeader in _request.requestHeaders)
				lines.push( header.name + ": " + header.value);
			
			var fullRequest:String = lines.join(CRLF) + CRLF + CRLF;
			
			_socket.writeUTFBytes(fullRequest);
			
			if(_request.data is URLVariables)
				_socket.writeUTFBytes( URLVariables(_request.data).toString() );
			else if(_request.data is ByteArray)
				_socket.writeBytes( _request.data );
			else if(_request.data is String)
				_socket.writeUTFBytes( _request.data );
				
			_socket.flush();
		}
		
		protected function onSocketData(e:ProgressEvent):void {
			if(_mode < MODE_DATA)
			{
				readLoop : while(_socket.bytesAvailable)
				{
					_responseData += _socket.readUTFBytes(1);
					
					if(_mode == MODE_PARSE_STATUS)
					{
						var httpStatusCheck:Object = RESPONSE_HTTP_STATUS_MATCH.exec(_responseData);
						if(httpStatusCheck && int(httpStatusCheck.status) == 100)
							httpStatusCheck = RESPONSE_HTTP_STATUS_MATCH.exec(_responseData);
						
						var icyStatusCheck:Object = RESPONSE_ICY_STATUS_MATCH.exec(_responseData);
						
						if(httpStatusCheck)
						{
							_status = int(httpStatusCheck.status);
							
							switch( _status )
							{
								case 200 :
									_mode = MODE_PARSE_HEADERS;
									_lastFoundIndex = RESPONSE_HTTP_STATUS_MATCH.lastIndex;
									break;
								
								default :
									close();
									errorCallback(_status);
									break readLoop;
							}
						}
						else if(icyStatusCheck)
						{
							_status = int(icyStatusCheck.status);
							
							switch(_status)
							{
								case 200 :
									_mode = MODE_PARSE_HEADERS;
									_lastFoundIndex = RESPONSE_ICY_STATUS_MATCH.lastIndex;
									break;
								
								default :
									close();
									errorCallback(_status);
									break readLoop;
							}
						}
					}
					else if(_mode == MODE_PARSE_HEADERS)
					{
						RESPONSE_HEADER_MATCH.lastIndex = _lastFoundIndex;
						
						var headerMatch:Object;
						while((headerMatch = RESPONSE_HEADER_MATCH.exec(_responseData)) != null)
						{
							_lastFoundIndex = RESPONSE_HEADER_MATCH.lastIndex;
							if(headerMatch.name.toLowerCase() == "content-length")
								_contentLength = int( headerMatch.value );
							_headers.push( new URLRequestHeader(headerMatch.name, headerMatch.value) );
						}
						
						if(_responseData.substr(_lastFoundIndex) == CRLF)
						{
							_mode = MODE_DATA;
							_responseData = null;
							responseCallback( _status, _headers );
							
							if(_progressCallback == null)
								_socket.removeEventListener(ProgressEvent.SOCKET_DATA, onSocketData);
							
							break;
						}
						
					}
				}
			}
			else if(progressCallback != null)
			{
				_loaded += e.bytesLoaded;
				progressCallback();
			}
		}
		
		protected function onSocketError(e:Event):void {
			if(_reconnectMode)
				planNextReconnect();
			else
				errorCallback(-1);
		}
	}
}
import flash.net.URLRequest;
import flash.net.URLRequestHeader;
import flash.net.URLVariables;
import flash.utils.ByteArray;

internal class HTTPRequest {
	public var port:int = 80;
	public var host:String;
	public var path:String;
	public var data:*;
	public var method:String;
	public var requestHeaders:Vector.<URLRequestHeader>;
	
	private static const MATCH_URL:RegExp = /(?P<protocol>http:\/\/|ftp:\/\/) (?:www\.)? (?P<host>[^\/:]+) (?P<path>\/.+)? (?:\: (?P<port>[0-9]+) )?/x;
	
	public function HTTPRequest(request:URLRequest):void {
		method = request.method;
		requestHeaders = Vector.<URLRequestHeader>(request.requestHeaders);
		
		var p:Object = request.url.match( MATCH_URL );
		host = p.host;
		path = p.path || "/";
		port = int(p.port) || 80;
		
		if(request.data != null)
		{
			var len:int;
			
			if(request.data is URLVariables)
				len = URLVariables(data).toString().length;
			else if(request.data is ByteArray)
				len = ByteArray(request.data).length;
			else if(request.data is String)
				len = request.data.length;
			
			setHeader("Content-Length", len.toString());
			setHeader("Content-Type", "application/x-www-form-urlencoded");
		}
		
		setHeader("Connection", "keep-alive");
		setHeader("Host", host);
		
		if(request.userAgent)
			setHeader("User-Agent", request.userAgent);
		
		if(request.contentType)
			setHeader("Content-Type", request.contentType);
	}
	
	private function setHeader(name:String, value:String):void {
		var foundHeader:URLRequestHeader;
		for each(var header:URLRequestHeader in requestHeaders)
		{
			if(header.name == name)
			{
				foundHeader = header;
				break;
			}
		}
		
		if(!foundHeader)
		{
			foundHeader = new URLRequestHeader(name, value);
			requestHeaders.push(foundHeader);
		}
		else
		{
			foundHeader.value = value;
		}
	}
}