//
//  MBSwizzler.swift
//  SwizzlingExample
//
//  Created by Max Bazaliy on 6/5/14.
//  Copyright (c) 2014 Home. All rights reserved.
//

import Foundation

extension NSObject {
	class func swizzleMethodSelector(origSelector: Selector, withSelector: Selector, forClass:AnyClass! = nil) -> Bool {

		var originalMethod: Method?
		var swizzledMethod: Method?

		let cls: AnyClass = forClass ?? self
		originalMethod = class_getInstanceMethod(cls, origSelector)
		swizzledMethod = class_getInstanceMethod(cls, withSelector)

		if (originalMethod != nil && swizzledMethod != nil) {
			method_exchangeImplementations(originalMethod!, swizzledMethod!)
			return true
		}
		return false
	}

	class func swizzleStaticMethodSelector(origSelector: Selector, withSelector: Selector, forClass:AnyClass! = nil) -> Bool {

		var originalMethod: Method?
		var swizzledMethod: Method?

		let cls: AnyClass = forClass ?? self
		originalMethod = class_getClassMethod(cls, origSelector)
		swizzledMethod = class_getClassMethod(cls, withSelector)

		if (originalMethod != nil && swizzledMethod != nil) {
			method_exchangeImplementations(originalMethod!, swizzledMethod!)
			return true
		}
		return false
	}
}
