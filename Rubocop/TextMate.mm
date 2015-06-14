//
//  TextMate.m
//  Rubocop
//
//  Created by doob on 2015-05-14.
//  Copyright (c) 2015 Jacob Carlborg. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "TextMate.h"

std::string to_s (NSString* aString)
{
	if(!aString)
		return NULL_STR;

	NSData* data = [aString dataUsingEncoding:NSUTF8StringEncoding];
	std::string res([data length], ' ');
	memcpy(&res[0], [data bytes], [data length]);
	return res;
}

extern "C"
{
	bool runRubocopEnabled (document_ptr document, NSString* scopeAttributes)
	{
		auto const settings = settings_for_path(document->virtual_path(),
												document->file_type() + " " +
												to_s(scopeAttributes),
												path::parent(document->path()));

		return settings.get("runRubocop", true);
	}

	bool isItemTypeGrammar (item_ptr item)
	{
		return item->kind() == bundles::kItemTypeGrammar;
	}
}
