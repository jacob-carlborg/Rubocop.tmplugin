//
//  Rubocop.swift
//  Rubocop
//
//  Created by doob on 2015-05-11.
//  Copyright (c) 2015 Jacob Carlborg. All rights reserved.
//

import Cocoa

@objc protocol TMPlugInController
{
	func version() -> Float32
}

@objc class Rubocop
{
	func initWithPlugInController(controller: TMPlugInController) -> AnyObject
	{
		let OakTextView = NSClassFromString("OakTextView") as? NSObject.Type
		OakTextView?.swizzleMethodSelector("setDocument:", withSelector: "rubocop_setDocument:")
		OakTextView?.swizzleMethodSelector("performBundleItem:", withSelector: "rubocop_performBundleItem:")

		NSLog("Rubocop.initWithPlugInController")
		return self
	}
}

private var isRubocopEnabledKey = 0
private var rubocopCounterKey = 1

extension OakTextView
{
	func rubocop_setDocument(document: UnsafeMutablePointer<Void>)
	{
		rubocop_setDocument(document)
		if hasDocument()
		{
			isRubocopEnabled = runRubocopEnabled(document, scopeAttributes());
			runRubocop()
		}
	}

	func checkRunRubocop()
	{
		if hasDocument()
		{
			isRubocopEnabled = runRubocopEnabled(rubocop_document, scopeAttributes())
		}
	}

	private func runRubocop()
	{
		if !isRubocopEnabled { return }
		NSLog("Run Rubcop")

		let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
		let time = dispatch_time(DISPATCH_TIME_NOW, Int64(NSEC_PER_SEC / 2))

		rubocopCounter++
		dispatch_async(dispatch_get_main_queue()) { self.clearAllMarks() }

		dispatch_after(time, queue) { self.onRunRubocop(queue) }
	}

	private func onRunRubocop (queue: dispatch_queue_t!)
	{
		if rubocopCounter > 1
		{
			rubocopCounter--
			return
		}

		let basePath = isOnDisk() ? dirName() : NSTemporaryDirectory()
		if basePath == nil
		{
			NSLog("Failed to get the base path")
			rubocopCounter--
			return
		}

		let tp = basePath + "/rubocop.XXXXXX"
		let uftCString = (tp as NSString).UTF8String

		let tempPath = strdup(uftCString)
		if tempPath == nil
		{
			NSLog("Failed to duplicate path")
			rubocopCounter--
			return
		}

		if mkstemp(tempPath) == -1
		{
			NSLog("Failed to create temporary path %s", String(UTF8String: tempPath)!)
			free(tempPath)
			rubocopCounter--
			return
		}

		writeContent(tempPath)
		let path = String(UTF8String: tempPath) ?? ""
		if path.isEmpty
		{
			NSLog("Failed to convert C string to String")
			free(tempPath)
			rubocopCounter--
			return
		}
		free(tempPath)

		var task = NSTask()
		task.launchPath = "/Users/doob/.rvm/gems/ruby-2.1.4/bin/rubocop"
		task.arguments = ["-f", "json", path]
		task.currentDirectoryPath = "/Users/doob"
		task.environment = rubocopEnv()

		let pipe = NSPipe()
		task.standardOutput = pipe
		task.standardError = pipe

		let file = pipe.fileHandleForReading
		task.launch()

		let data = file.readDataToEndOfFile()
		file.closeFile()

		dispatch_async(queue)
		{
			var error: NSError?
			let removed = NSFileManager.defaultManager().removeItemAtPath(path, error: &error)

			if !removed
			{
				NSLog("Failed to remove temporary rubocop file: '%@' with error: %@", path, error!)
			}
		}

		parseRubocopJSONWithData(data)
	}

	private func parseRubocopJSONWithData(data: NSData)
	{
		var error: NSError?
		let json: AnyObject? = NSJSONSerialization.JSONObjectWithData(data, options: .MutableContainers, error: &error)

		if let err = error { NSLog("Failed to parse JSON result: %@", err); return }

		if let offenses = (((json as? NSDictionary)?["files"] as? [AnyObject])?[0] as? NSDictionary)?["offenses"] as? [AnyObject]
		{
			let mainQueue = dispatch_get_main_queue()

			for value in offenses
			{
				if let offense = value as? NSDictionary
				{
					let message = offense["message"] as? String ?? ""
					let line = (offense["location"] as? NSDictionary)?["line"] as? Int ?? 0

					if !message.isEmpty && line > 0
					{
						dispatch_async(mainQueue) { self.appendMark(message, line: UInt(line)) }
					}
				}
			}
		}

		/*if let root = json as? NSDictionary
		{
			if let files = root["files"] as? NSArray
			{
				if files.count == 0 { return false }

				if let file = files[0] as? NSDictionary
				{
					if let offenses = file["offenses"] as? NSArray
					{
						if offenses.count == 0 { return false}

						let mainQueue = dispatch_get_main_queue()

						for value in offenses
						{
							if let offense = value as? NSDictionary
							{
								let message = offense["message"] as? String ?? ""
								let location = offense["location"] as? NSDictionary ?? NSDictionary()
								let line = location["line"] as? Int ?? 0

								if !message.isEmpty && line > 0
								{
									dispatch_async(mainQueue) { self.appendMark(message, line: UInt(line)) }
								}
							}
						}
					}
				}
			}
		}*/
	}

	private func rubocopEnv () -> [NSObject : AnyObject]
	{
		var env = NSProcessInfo.processInfo().environment
		let binPaths = ":/Users/doob/.rvm/gems/ruby-2.1.4/bin/rubocop"
		let path = env["PATH"] as? String ?? ""

		env["PATH"] = path + binPaths
		env["GEM_HOME"] = "/Users/doob/.rvm/gems/ruby-2.1.4"

		return env
	}

	private func associatedObject<T>(key: UnsafePointer<Void>, defaultValue: T) -> T
	{
		return objc_getAssociatedObject(self, key) as? T ?? defaultValue
	}

	private func setAssociatedObject<T : AnyObject>(key: UnsafePointer<Void>, value: T)
	{
		objc_setAssociatedObject(self, key, value,
			objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN))
	}

	var isRubocopEnabled: Bool
	{
		get { return associatedObject(&isRubocopEnabledKey, defaultValue: false) }

		set(value)
		{
			let val: NSNumber = value
			setAssociatedObject(&isRubocopEnabledKey, value: val)
		}
	}

	private var rubocopCounter: Int
	{
		get { return associatedObject(&rubocopCounterKey, defaultValue: 0) }

		set(value)
		{
			setAssociatedObject(&rubocopCounterKey, value: NSNumber(integer: value))
		}
	}
}