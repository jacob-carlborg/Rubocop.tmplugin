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
		NSLog("foo")
		return self
	}
}