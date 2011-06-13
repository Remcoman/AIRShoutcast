package nl.remcokrams.shoutcast
{
	import flash.net.URLRequestHeader;
	import flash.utils.ByteArray;
	
	/**
	 *	Created by remcokrams
	 *	Apr 25, 2011	
	 **/
	
	public class StreamInfo
	{
		public static const ARTIST:String = "artist";
		public static const GENRE:String  = "genre";
		public static const TITLE:String  = "title";
		public static const STATION_URL:String  = "station_url";
		
		public var bitRate:uint;
		public var metadataBytes:uint;
		public var contentType:String;
		public var url:String;
		
		protected var _isValid:Boolean;
		protected var _properties:Object;
		
		public function StreamInfo( url:String ):void {
			this.url = url;
		}
		
		public function reset():void {
			bitRate = 0;
			metadataBytes = 0;
			contentType = null;
			_properties = {};
			_isValid = false;
		}
		
		public function hasProperty(name:String):Boolean {
			return name in _properties;
		}
		
		public function setProperties(props:Object):void {
			for(var name:String in props)
				_properties[name] = props[name];
		}
		
		public function setProperty(name:String, value:String):void {
			_properties[name] = value;
		}
		
		public function getProperty(name:String, defaultValue:String=""):String {
			if(name in _properties)
				return _properties[ name ];
			return defaultValue;
		}
		
		public function get isValid():Boolean {
			return _isValid;
		}
		
		protected function parseSingleHeader(headerName:String, headerValue:String):void {
			switch( headerName.toLowerCase() )
			{
				case "icy-metaint" :
					metadataBytes = int( headerValue );
					break;
				
				case "content-type" :
					contentType = headerValue;
					break;
				
				case "icy-br" :
					bitRate = uint( headerValue );
					break;
				
				case "icy-genre" :
					setProperty(GENRE, headerValue);
					break;
				
				case "icy-url" :
					setProperty(STATION_URL, headerValue);
					break;
				
				case "icy-name" :
					setProperty(TITLE, headerValue);
					break;
			}
		}
		
		public function parseFromHeaders(headers:Vector.<URLRequestHeader>):Boolean {
			reset();
			
			for each(var header:URLRequestHeader in headers)
				parseSingleHeader(header.name, header.value);
			
			_isValid = contentType != null && metadataBytes > 0;
			
			return _isValid;
		}
		
		public function parseFromBody(buffer:ByteArray):Boolean {
			reset();
			
			const MATCH_HEADER_LINE:RegExp = /(ICY[\s]200[\s]OK | (?P<name>[^:]+)[\s]*:[\s]*(?P<value>[^\r\n]+) |)\r\n/gx;
			var header:String = buffer.readUTFBytes(buffer.bytesAvailable), match:Object, i:int=0, endLineEnd:uint=0;
			
			while( match = MATCH_HEADER_LINE.exec(header) ) {
				if(i++ == 0)
				{
					if(match[1] != "ICY 200 OK")
						break; //INVALID HEADER
				}
				else if(match[1] == "")
				{
					endLineEnd = MATCH_HEADER_LINE.lastIndex;
					break; //LAST LINE OF HEADER
				}
				else
				{
					parseSingleHeader(match['name'], match['value']);
				}
			}
			
			_isValid = contentType != null && metadataBytes > 0;
			
			buffer.position = endLineEnd;
			
			return _isValid;
		}
	}
}