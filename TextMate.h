//
//  TextMate.h
//  Rubocop
//
//  Created by doob on 2015-05-14.
//  Copyright (c) 2015 Jacob Carlborg. All rights reserved.
//

#ifndef Rubocop_TextMate_h
#define Rubocop_TextMate_h

#import <string>
#import <map>
#import <memory>
#import <vector>
#import <fstream>

#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>

#import "indexed_map.h"

#define opaque int8_t
#define NULL_STR std::string()

struct settings_t
{
	template <typename T> T get (std::string const& key, T const& defaultValue) const
	{
		std::map<std::string, std::string>::const_iterator it = settings.find(key);
		return it == settings.end() ? defaultValue : convert(it->second, defaultValue);
	}

private:
	static bool convert (std::string const& value, bool)  { return value != "0" && value != "false" ? true : false; }
	std::map<std::string, std::string> settings;
};

namespace scope
{
	struct scope_t
	{
		scope_t ();
		scope_t (char const* scope);
		scope_t (std::string const& scope);
	};
}

namespace path
{
	std::string parent (std::string const& path);
	bool exists (std::string const& path);
	std::string parent (std::string const& path);
}

namespace ng
{
	struct marks_t
	{
		void append (size_t index, std::string const& markType, std::string const& markData);
	};

	struct buffer_t
	{
		void append_mark (size_t index, std::string const& markType, std::string const& markData) { return _marks->append(index, markType, markData); }
		size_t begin (size_t n) const { return n == 0 ? 0 : _hardlines.nth(n-1)->first + 1; }

		//opaque _instance_counter_helper[8];
		opaque _callbacks[88];
		opaque _meta_data[24];
		//std::vector<void*> _meta_data;
		opaque _grammar[16];
		opaque _grammar_callback[16];
		opaque _indent[24];
		std::shared_ptr<bool> _parser_reference;
		bool _async_parsing = false;
		size_t _revision, _next_revision;
		std::string _spelling_language;
		opaque _spelling_tag[16];

		opaque _storage[16];
		indexed_map_t<bool> _hardlines;
		opaque _dirty[16];
		opaque _scopes[16];
		opaque _parser_states[16];

		opaque _spelling[16];
		opaque _symbols[16];
		std::shared_ptr<marks_t> _marks;
		opaque _pairs[16];
	};
}

/*template<int s> struct Wow;
struct foo {
	int a,b;
};
Wow<sizeof(ng::buffer_t)> wow;*/

static_assert(sizeof(ng::buffer_t) == 392, "size of ng::buffer_t not 392");

namespace document
{
	struct document_t : std::enable_shared_from_this<document_t>
	{
		std::string path () const { return _path; }
		std::string virtual_path () const { return _virtual_path == NULL_STR ? _path : _virtual_path; }
		std::string file_type () const
		{
			return _file_type;
		}

		bool is_open () const{ return _open_count != 0 && !_open_callback; }
		bool is_on_disk () const { return is_open() ? _is_on_disk : path::exists(path()); }

		void remove_all_marks (std::string const& typeToClear = NULL_STR);
		ng::buffer_t& buffer () { return *_buffer; }
		std::string content () const;

	private:

		opaque _instance_counter_helper[8];
		std::string _selection;
		std::string _folded;
		opaque _visible_index[16];
		opaque _content[16];
		opaque _callbacks[88];
		bool _disable_callbacks;
		opaque _open_callback[16];
		opaque _identifier[16];
		opaque _inode[16];
		ssize_t _revision;
		ssize_t _disk_revision;
		bool _modified;
		std::string _path;                    // does not imply there actually is a file
		size_t _open_count;                   // document open in some window/tab
		mutable opaque _lru[8];             // last time document was shown
		mutable bool _has_lru;
		bool _is_on_disk;
		bool _recent_tracking;
		bool _sticky = false;

		mutable std::string _backup_path;     // if there is a backup, this is set — we can have a backup even when there is no path
		mutable ssize_t _backup_revision;

		std::string _virtual_path;
		std::string _custom_name;
		mutable size_t _untitled_count;       // this is ≠ 0 if the document is untitled

		mutable std::string _file_type;       // this may also be in the settings
		// oak::uuid_t _grammar_uuid;

		std::shared_ptr<ng::buffer_t> _buffer;
		std::string _pristine_buffer = NULL_STR;
		opaque _undo_manager[16];
		opaque _authorization[16];
		std::string _disk_encoding;
		std::string _disk_newlines;
		bool _disk_bom;

		opaque _indent[24];
		opaque _file_watcher[16];
	};
}

static_assert(sizeof(document::document_t) == 600, "size of document::document_t not 600");
typedef std::shared_ptr<document::document_t> document_ptr;

namespace bundles
{
	enum kind_t
	{
		kItemTypeGrammar = 4,
	};

	struct item_t
	{
		kind_t kind () const;
	};
}

typedef std::shared_ptr<bundles::item_t> item_ptr;

settings_t settings_for_path (std::string const& path = NULL_STR, scope::scope_t const& scope = "", std::string const& directory = NULL_STR, std::map<std::string, std::string> variables = std::map<std::string, std::string>());
std::string to_s (NSString* aString);

extern "C"
{
	bool runRubocopEnabled (std::shared_ptr<document::document_t> document, NSString* scopeAttributes);
}

@interface OakTextView : NSView
- (NSString*)scopeAttributes;
@end

@interface OakTextView (Rubocop)

@property(readonly) document_ptr rubocop_document;
@property BOOL isRubocopEnabled;
- (void) runRubocop;
@end

@implementation OakTextView (Rubocop)

- (void)performBundleItem:(item_ptr)item
{
	if (item->kind() == bundles::kItemTypeGrammar)
		[self checkRunRubocop];
}

- (document_ptr) rubocop_document
{
	auto ivar = class_getInstanceVariable([self class], "document");
	auto result = (__bridge void*) object_getIvar(self, ivar);
	return *(document_ptr*)&result;
}

- (BOOL) hasDocument
{
	return self.rubocop_document != nullptr;
}

- (void) clearAllMarks
{
	if (self.rubocop_document)
	{
		self.rubocop_document->remove_all_marks("error");
		[self setNeedsDisplay:YES];
	}
}

- (void) appendMark:(NSString*)data line:(NSUInteger)aLine
{
	if (self.rubocop_document)
	{
		auto& buf = self.rubocop_document->buffer();
		buf.append_mark(buf.begin(aLine - 1), "error", to_s(data));
		[self setNeedsDisplay:YES];
	}
}

- (BOOL) isOnDisk
{
	return self.rubocop_document->is_on_disk();
}

- (NSString*) dirName
{
	auto dirName = path::parent(self.rubocop_document->path());
	return [NSString stringWithUTF8String:dirName.c_str()];
}

- (void) writeContent:(const char*)path
{
	std::ofstream tempFile;
	tempFile.open(path);
	tempFile << self.rubocop_document->content();
	tempFile.close();
}

- (void) checkRunRubocop
{
	if (!self.rubocop_document)
		return;

	self.isRubocopEnabled = runRubocopEnabled(self.rubocop_document, [self scopeAttributes]);
}
@end

namespace ng
{
	struct callback_t
	{
		virtual void did_replace (size_t from, size_t to, std::string const& str)  { }
	};
}

struct RubocopCallback : ng::callback_t
{
	OakTextView* textView;

	virtual void did_replace (size_t from, size_t to, std::string const& str)
	{
		[textView runRubocop];
	}
};

#endif
