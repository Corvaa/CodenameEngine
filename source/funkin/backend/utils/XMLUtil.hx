package funkin.backend.utils;

import flixel.animation.FlxAnimation;
import funkin.backend.FunkinSprite;
import funkin.backend.system.ErrorCode;
import funkin.backend.FunkinSprite.XMLAnimType;
import funkin.backend.system.interfaces.IBeatReceiver;
import haxe.xml.Access;
import funkin.backend.system.interfaces.IOffsetCompatible;

using StringTools;
/**
 * Class made to make XML parsing easier.
 */
class XMLUtil {

	/**
	 * Applies a property XML node to an object.
	 * @param object Object to which the xml property will be applied
	 * @param property `property` node.
	 */
	public static function applyXMLProperty(object:Dynamic, property:Access):ErrorCode {
		if (!property.has.name || !property.has.type || !property.has.value) {
			Logs.trace('Failed to apply XML property: XML Element is missing name, type, or value attributes.', WARNING);
			return MISSING_PROPERTY;
		}

		var keys = property.att.name.split(".");
		var o = object;
		var isPath = false;
		while(keys.length > 1) {
			isPath = true;
			o = Reflect.getProperty(o, keys.shift());
			// TODO: support arrays
		}

		var value:Dynamic = switch(property.att.type.toLowerCase()) {
			case "f" | "float" | "number":			Std.parseFloat(property.att.value);
			case "i" | "int" | "integer" | "color":	Std.parseInt(property.att.value);
			case "s" | "string" | "str" | "text":	property.att.value;
			case "b" | "bool" | "boolean":			property.att.value.toLowerCase() == "true";
			default:								return TYPE_INCORRECT;
		}
		if (value == null) return VALUE_NULL;

		if (object is IXMLEvents) {
			cast(object, IXMLEvents).onPropertySet(property.att.name, value);
		}

		try {
			Reflect.setProperty(o, keys[0], value);
		} catch(e) {
			var str = 'Failed to apply XML property: $e on ${Type.getClass(object)}';
			if(isPath) {
				str += ' (Path: ${property.att.name})';
			}
			Logs.trace(str, WARNING);
			return REFLECT_ERROR;
		}
		return OK;
	}

	/**
	 * Creates a new sprite based on a XML node.
	 */
	public static function createSpriteFromXML(node:Access, parentFolder:String = "", defaultAnimType:XMLAnimType = BEAT, ?cl:Class<FunkinSprite>):FunkinSprite {
		if (parentFolder == null) parentFolder = "";

		var spr:FunkinSprite = cl != null ? Type.createInstance(cl, []) : new FunkinSprite();
		spr.name = node.getAtt("name");
		spr.antialiasing = true;

		spr.loadSprite(Paths.image('$parentFolder${node.getAtt("sprite")}', null, true));

		spr.spriteAnimType = defaultAnimType;
		if (node.has.type) {
			spr.spriteAnimType = XMLAnimType.fromString(node.att.type, spr.spriteAnimType);
		}

		if(node.has.x) {
			var x:Null<Float> = Std.parseFloat(node.att.x);
			if (x.isNotNull()) spr.x = x;
		}
		if(node.has.y) {
			var y:Null<Float> = Std.parseFloat(node.att.y);
			if (y.isNotNull()) spr.y = y;
		}
		if (node.has.scroll) {
			var scroll:Null<Float> = Std.parseFloat(node.att.scroll);
			if (scroll.isNotNull()) spr.scrollFactor.set(scroll, scroll);
		} else {
			if (node.has.scrollx) {
				var scroll:Null<Float> = Std.parseFloat(node.att.scrollx);
				if (scroll.isNotNull()) spr.scrollFactor.x = scroll;
			}
			if (node.has.scrolly) {
				var scroll:Null<Float> = Std.parseFloat(node.att.scrolly);
				if (scroll.isNotNull()) spr.scrollFactor.y = scroll;
			}
		}
		if (node.has.skewx) {
			var skew:Null<Float> = Std.parseFloat(node.att.skewx);
			if (skew.isNotNull()) spr.skew.x = skew;
		}
		if (node.has.skewy) {
			var skew:Null<Float> = Std.parseFloat(node.att.skewy);
			if (skew.isNotNull()) spr.skew.y = skew;
		}
		if (node.has.antialiasing) spr.antialiasing = node.att.antialiasing == "true";
		if (node.has.scale) {
			var scale:Null<Float> = Std.parseFloat(node.att.scale);
			if (scale.isNotNull()) spr.scale.set(scale, scale);
		}
		if (node.has.scalex) {
			var scale:Null<Float> = Std.parseFloat(node.att.scalex);
			if (scale.isNotNull()) spr.scale.x = scale;
		}
		if (node.has.scaley) {
			var scale:Null<Float> = Std.parseFloat(node.att.scaley);
			if (scale.isNotNull()) spr.scale.y = scale;
		}
		if (node.has.updateHitbox && node.att.updateHitbox == "true") spr.updateHitbox();

		if(node.has.zoomfactor)
			spr.zoomFactor = Std.parseFloat(node.getAtt("zoomfactor")).getDefault(spr.zoomFactor);

		if (node.has.alpha)
			spr.alpha = Std.parseFloat(node.getAtt("alpha")).getDefault(spr.alpha);

		if (node.has.playOnCountdown)
			spr.skipNegativeBeats = node.att.playOnCountdown == "true";
		if (node.has.beatInterval)
			spr.beatInterval = Std.parseInt(node.att.beatInterval);
		if (node.has.beatOffset)
			spr.beatOffset = Std.parseInt(node.att.beatOffset);

		if(node.hasNode.anim) {
			for(anim in node.nodes.anim)
				addXMLAnimation(spr, anim);
		} else {
			if (spr.frames != null && spr.frames.frames != null) {
				addAnimToSprite(spr, {
					name: "idle",
					anim: null,
					fps: 24,
					loop: spr.spriteAnimType == LOOP,
					animType: spr.spriteAnimType,
					x: 0,
					y: 0,
					indices: [for(i in 0...spr.frames.frames.length) i],
					forced: (node.has.forced && node.att.forced == "true") || (!node.has.forced && spr.spriteAnimType == BEAT)
				});
			}
		}

		return spr;
	}

	public static function extractAnimFromXML(anim:Access, animType:XMLAnimType = NONE, loop:Bool = false):AnimData {
		var animData:AnimData = {
			name: null,
			anim: null,
			fps: 24,
			loop: loop,
			animType: animType,
			x: 0,
			y: 0,
			indices: [],
			forced: false,
		};

		if (anim.has.name) animData.name = anim.att.name;
		if (anim.has.type) animData.animType = XMLAnimType.fromString(anim.att.type, animData.animType);
		if (anim.has.anim) animData.anim = anim.att.anim;
		if (anim.has.fps) animData.fps = Std.parseFloat(anim.att.fps).getDefault(animData.fps);
		if (anim.has.x) animData.x = Std.parseFloat(anim.att.x).getDefault(animData.x);
		if (anim.has.y) animData.y = Std.parseFloat(anim.att.y).getDefault(animData.y);
		if (anim.has.loop) animData.loop = anim.att.loop == "true";
		if (anim.has.forced) animData.forced = anim.att.forced == "true";
		if (anim.has.indices) {
			var indicesSplit = anim.att.indices.split(",");
			for(indice in indicesSplit) {
				var i = Std.parseInt(indice.trim());
				if (i != null)
					animData.indices.push(i);
			}
		}

		return animData;
	}
	/**
	 * Adds an XML animation to `sprite`.
	 * @param sprite Destination sprite
	 * @param anim Animation (Must be a `anim` XML node)
	 */
	public static function addXMLAnimation(sprite:FlxSprite, anim:Access, loop:Bool = false):ErrorCode {
		var animType:XMLAnimType = NONE;
		if (sprite is FunkinSprite) {
			animType = cast(sprite, FunkinSprite).spriteAnimType;
		}

		return addAnimToSprite(sprite, extractAnimFromXML(anim, animType, loop));
	}

	public static function addAnimToSprite(sprite:FlxSprite, animData:AnimData):ErrorCode {
		if (animData.name != null) {
			if (animData.fps <= 0 #if web || animData.fps == null #end) animData.fps = 24;

			if (sprite is FunkinSprite && cast(sprite, FunkinSprite).animateAtlas != null) {
				var animateAnim = cast(sprite, FunkinSprite).animateAtlas.anim;
				if(animData.anim == null)
					return MISSING_PROPERTY;

				if (animData.indices.length > 0)
					animateAnim.addBySymbolIndices(animData.name, animData.anim, animData.indices, animData.fps, animData.loop);
				else
					animateAnim.addBySymbol(animData.name, animData.anim, animData.fps, animData.loop);
			} else {
				if (animData.anim == null && animData.indices.length > 0)
					sprite.animation.add(animData.name, animData.indices, animData.fps, animData.loop);
				else if (animData.indices.length > 0)
					sprite.animation.addByIndices(animData.name, animData.anim, animData.indices, "", animData.fps, animData.loop);
				else
					sprite.animation.addByPrefix(animData.name, animData.anim, animData.fps, animData.loop);
			}

			if (sprite is IOffsetCompatible)
				cast(sprite, IOffsetCompatible).addOffset(animData.name, animData.x, animData.y);

			if (sprite is FunkinSprite) {
				var xmlSpr = cast(sprite, FunkinSprite);
				switch(animData.animType) {
					case BEAT:
						xmlSpr.beatAnims.push({
							name: animData.name,
							forced: animData.forced.getDefault(false)
						});
					case LOOP:
						xmlSpr.animation.play(animData.name, animData.forced.getDefault(false));
					default:
						// nothing
				}
				xmlSpr.animDatas.set(animData.name, animData);
			}
			return OK;
		}
		return MISSING_PROPERTY;
	}

	public static inline function fixXMLText(text:String) {
		var v:String;
		return [for(l in text.split("\n")) if ((v = l.trim()) != "") v].join("\n");
	}
}

typedef AnimData = {
	var name:String;
	var anim:String;
	var fps:Float;
	var loop:Bool;
	var x:Float;
	var y:Float;
	var indices:Array<Int>;
	var animType:XMLAnimType;
	var ?forced:Bool;
}

typedef BeatAnim = {
	var name:String;
	var forced:Bool;
}

interface IXMLEvents {
	public function onPropertySet(property:String, value:Dynamic):Void;
}