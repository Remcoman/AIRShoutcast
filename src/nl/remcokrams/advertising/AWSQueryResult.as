package nl.remcokrams.advertising
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.system.System;
	
	/**
	 *	Created by remcokrams
	 *	Jun 5, 2011	
	 **/
	
	[Event(type='flash.events.Event', name='complete')]
	
	public class AWSQueryResult extends EventDispatcher
	{
		public static const SWATCH_IMAGE:String = "SwatchImage";
		public static const SMALL_IMAGE:String = "SmallImage";
		public static const MEDIUM_IMAGE:String = "MediumImage";
		public static const LARGE_IMAGE:String = "LargeImage";
		
		public var operation:String;
		
		private var _loader:URLLoader;
		private var _data:XML;
		private var _resultCount:int;
		private var _items:XMLList;
		
		public static const ans:Namespace = new Namespace("", "http://webservices.amazon.com/AWSECommerceService/2010-11-01");
		
		public function AWSQueryResult(operation:String, loader:URLLoader)
		{
			this.operation = operation;
			
			_loader = loader;
			_loader.dataFormat = URLLoaderDataFormat.TEXT;
			_loader.addEventListener(Event.COMPLETE, onComplete);
		}
		
		public function abort():void {
			try {
				_loader.close();
			}
			catch(e:Error) {};
		}
		
		public function dispose():void {
			abort();
			System.disposeXML(_data);
			_data = null;
			_items = null;
			_loader = null;
			_resultCount = 0;
		}
		
		private function onComplete(e:Event):void {
			_data = XML( _loader.data );
			
			_resultCount = int(_data.ans::Items.ans::TotalResults);
			_items = _data.ans::Items.ans::Item;
			dispatchEvent(e);
		}
		
		public function get resultCount():int {
			return _resultCount;
		}
		
		public function getItem(index:int=0):XML {
			return _items[index];
		}
		
		public function getImage(index:int=0, type:String=LARGE_IMAGE):String {
			var item:XML = getItem(index);
			var qName:QName = new QName(ans, type);
			return item ? item.elements(qName)[0].ans::URL.toString() : null;
		}
	}
}