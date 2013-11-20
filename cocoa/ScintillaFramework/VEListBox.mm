//
//  VEListBox.mm
//  Scintilla
//
//  Created by Mac003 on 13-11-20.
//
//

#import "Platform.h"

#import "Scintilla.h"
#import "PlatCocoa.h"

#include <string>
#include <vector>
#include <map>

#import "XPM.h"

#import "ScintillaPrivate.h"
#import <Cocoa/Cocoa.h>

using namespace Scintilla;

//----------------- ListBox and related classes ----------------------------------------------------

namespace {
    
    // unnamed namespace hides IListBox interface
    
    class IListBox {
    public:
        virtual int Rows() = 0;
        virtual NSImage* ImageForRow(NSInteger row) = 0;
        virtual NSString* TextForRow(NSInteger row) = 0;
        virtual void DoubleClick() = 0;
    };
    
} // unnamed namespace

//----------------- AutoCompletionDataSource -------------------------------------------------------

@interface AutoCompletionDataSource : NSObject<NSTableViewDataSource>
{
    IListBox* box;
}

@property IListBox* box;

@end

@implementation AutoCompletionDataSource

@synthesize box;

- (void) doubleClick: (id) sender
{
	if (box)
	{
		box->DoubleClick();
	}
}

- (id)          tableView: (NSTableView*)aTableView
objectValueForTableColumn: (NSTableColumn*)aTableColumn
                      row: (NSInteger)rowIndex
{
	if (!box)
		return nil;
	if ([(NSString*)[aTableColumn identifier] isEqualToString: @"icon"])
	{
		return box->ImageForRow(rowIndex);
	}
	else {
		return box->TextForRow(rowIndex);
	}
}

- (void)tableView: (NSTableView*)aTableView
   setObjectValue: anObject
   forTableColumn: (NSTableColumn*)aTableColumn
              row: (NSInteger)rowIndex
{
}

- (NSInteger)numberOfRowsInTableView: (NSTableView*)aTableView
{
	if (!box)
		return 0;
	return box->Rows();
}

@end

//----------------- ImageFromXPM -------------------------------------------------------------------

// Convert an XPM image into an NSImage for use with Cocoa

static NSImage* ImageFromXPM(XPM* pxpm)
{
    NSImage* img = nil;
    if (pxpm)
    {
        const int width = pxpm->GetWidth();
        const int height = pxpm->GetHeight();
        PRectangle rcxpm(0, 0, width, height);
        Surface* surfaceXPM = Surface::Allocate(SC_TECHNOLOGY_DEFAULT);
        if (surfaceXPM)
        {
            surfaceXPM->InitPixMap(width, height, NULL, NULL);
            SurfaceImpl* surfaceIXPM = static_cast<SurfaceImpl*>(surfaceXPM);
            CGContextClearRect(surfaceIXPM->GetContext(), CGRectMake(0, 0, width, height));
            pxpm->Draw(surfaceXPM, rcxpm);
            img = [[[NSImage alloc] initWithSize:NSZeroSize] autorelease];
            CGImageRef imageRef = surfaceIXPM->GetImage();
            NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithCGImage: imageRef];
            [img addRepresentation: bitmapRep];
            [bitmapRep release];
            CGImageRelease(imageRef);
            delete surfaceXPM;
        }
    }
    return img;
}

//----------------- ListBoxImpl --------------------------------------------------------------------

namespace
{	// unnamed namespace hides ListBoxImpl and associated classes
    
    struct RowData
    {
        int type;
        std::string text;
        RowData(int type_, const char* text_) :
        type(type_), text(text_)
        {
        }
    };
    
    class LinesData
    {
        std::vector<RowData> lines;
    public:
        LinesData()
        {
        }
        ~LinesData()
        {
        }
        int Length() const
        {
            return static_cast<int>(lines.size());
        }
        void Clear()
        {
            lines.clear();
        }
        void Add(int /* index */, int type, char* str)
        {
            lines.push_back(RowData(type, str));
        }
        int GetType(size_t index) const
        {
            if (index < lines.size())
            {
                return lines[index].type;
            }
            else
            {
                return 0;
            }
        }
        const char* GetString(size_t index) const
        {
            if (index < lines.size())
            {
                return lines[index].text.c_str();
            }
            else
            {
                return 0;
            }
        }
    };
    
    // Map from icon type to an NSImage*
    typedef std::map<NSInteger, NSImage*> ImageMap;
    
    class ListBoxImpl : public ListBox, IListBox
    {
    private:
        ImageMap images;
        int lineHeight;
        bool unicodeMode;
        int desiredVisibleRows;
        unsigned int maxItemWidth;
        unsigned int aveCharWidth;
        unsigned int maxIconWidth;
        Font font;
        int maxWidth;
        
        NSTableView* table;
        NSScrollView* scroller;
        NSTableColumn* colIcon;
        NSTableColumn* colText;
        AutoCompletionDataSource* ds;
        
        LinesData ld;
        CallBackAction doubleClickAction;
        void* doubleClickActionData;
        
    public:
        ListBoxImpl() : lineHeight(10), unicodeMode(false),
        desiredVisibleRows(5), maxItemWidth(0), aveCharWidth(8), maxIconWidth(0),
        doubleClickAction(NULL), doubleClickActionData(NULL)
        {
        }
        ~ListBoxImpl() {}
        
        // ListBox methods
        void SetFont(Font& font);
        void Create(Window& parent, int ctrlID, Scintilla::Point pt, int lineHeight_, bool unicodeMode_, int technology_);
        void SetAverageCharWidth(int width);
        void SetVisibleRows(int rows);
        int GetVisibleRows() const;
        PRectangle GetDesiredRect();
        int CaretFromEdge();
        void Clear();
        void Append(char* s, int type = -1);
        int Length();
        void Select(int n);
        int GetSelection();
        int Find(const char* prefix);
        void GetValue(int n, char* value, int len);
        void RegisterImage(int type, const char* xpm_data);
        void RegisterRGBAImage(int type, int width, int height, const unsigned char *pixelsImage);
        void ClearRegisteredImages();
        void SetDoubleClickAction(CallBackAction action, void* data)
        {
            doubleClickAction = action;
            doubleClickActionData = data;
        }
        void SetList(const char* list, char separator, char typesep);
        
        // For access from AutoCompletionDataSource implement IListBox
        int Rows();
        NSImage* ImageForRow(NSInteger row);
        NSString* TextForRow(NSInteger row);
        void DoubleClick();
    };
    
    void ListBoxImpl::Create(Window& /*parent*/, int /*ctrlID*/, Scintilla::Point pt,
                             int lineHeight_, bool unicodeMode_, int)
    {
        lineHeight = lineHeight_;
        unicodeMode = unicodeMode_;
        maxWidth = 2000;
        
        NSRect lbRect = NSMakeRect(pt.x,pt.y, 120, lineHeight * desiredVisibleRows);
        NSWindow* winLB = [[NSWindow alloc] initWithContentRect: lbRect
                                                      styleMask: NSBorderlessWindowMask
                                                        backing: NSBackingStoreBuffered
                                                          defer: NO];
        [winLB setLevel:NSFloatingWindowLevel];
        [winLB setHasShadow:YES];
        scroller = [NSScrollView alloc];
        NSRect scRect = NSMakeRect(0, 0, lbRect.size.width, lbRect.size.height);
        [scroller initWithFrame: scRect];
        [scroller setHasVerticalScroller:YES];
        table = [[NSTableView alloc] initWithFrame: scRect];
        [table setHeaderView:nil];
        [scroller setDocumentView: table];
        colIcon = [[NSTableColumn alloc] initWithIdentifier:@"icon"];
        [colIcon setWidth: 20];
        [colIcon setEditable:NO];
        [colIcon setHidden:YES];
        NSImageCell* imCell = [[[NSImageCell alloc] init] autorelease];
        [colIcon setDataCell:imCell];
        [table addTableColumn:colIcon];
        colText = [[NSTableColumn alloc] initWithIdentifier:@"name"];
        [colText setResizingMask:NSTableColumnAutoresizingMask];
        [colText setEditable:NO];
        [table addTableColumn:colText];
        ds = [[AutoCompletionDataSource alloc] init];
        [ds setBox:this];
        [table setDataSource: ds];	// Weak reference
        [scroller setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
        [[winLB contentView] addSubview: scroller];
        
        [table setTarget:ds];
        [table setDoubleAction:@selector(doubleClick:)];
        wid = winLB;
    }
    
    void ListBoxImpl::SetFont(Font& font_)
    {
        // NSCell setFont takes an NSFont* rather than a CTFontRef but they
        // are the same thing toll-free bridged.
        QuartzTextStyle* style = reinterpret_cast<QuartzTextStyle*>(font_.GetID());
        font.Release();
        font.SetID(new QuartzTextStyle(*style));
        NSFont *pfont = (NSFont *)style->getFontRef();
        [[colText dataCell] setFont: pfont];
        CGFloat itemHeight = ceil([pfont boundingRectForFont].size.height);
        [table setRowHeight:itemHeight];
    }
    
    void ListBoxImpl::SetAverageCharWidth(int width)
    {
        aveCharWidth = width;
    }
    
    void ListBoxImpl::SetVisibleRows(int rows)
    {
        desiredVisibleRows = rows;
    }
    
    int ListBoxImpl::GetVisibleRows() const
    {
        return desiredVisibleRows;
    }
    
    PRectangle ListBoxImpl::GetDesiredRect()
    {
        PRectangle rcDesired;
        rcDesired = GetPosition();
        
        // There appears to be an extra pixel above and below the row contents
        int itemHeight = [table rowHeight] + 2;
        
        int rows = Length();
        if ((rows == 0) || (rows > desiredVisibleRows))
            rows = desiredVisibleRows;
        
        rcDesired.bottom = rcDesired.top + itemHeight * rows;
        rcDesired.right = rcDesired.left + maxItemWidth + aveCharWidth;
        
        if (Length() > rows)
        {
            [scroller setHasVerticalScroller:YES];
            rcDesired.right += [NSScroller scrollerWidth];
        }
        else
        {
            [scroller setHasVerticalScroller:NO];
        }
        rcDesired.right += maxIconWidth;
        rcDesired.right += 6;
        
        return rcDesired;
    }
    
    int ListBoxImpl::CaretFromEdge()
    {
        if ([colIcon isHidden])
            return 3;
        else
            return 6 + [colIcon width];
    }
    
    void ListBoxImpl::Clear()
    {
        maxItemWidth = 0;
        maxIconWidth = 0;
        ld.Clear();
    }
    
    void ListBoxImpl::Append(char* s, int type)
    {
        int count = Length();
        ld.Add(count, type, s);
        
        Scintilla::SurfaceImpl surface;
        unsigned int width = surface.WidthText(font, s, static_cast<int>(strlen(s)));
        if (width > maxItemWidth)
        {
            maxItemWidth = width;
            [colText setWidth: maxItemWidth];
        }
        ImageMap::iterator it = images.find(type);
        if (it != images.end())
        {
            NSImage* img = it->second;
            if (img)
            {
                unsigned int widthIcon = img.size.width;
                if (widthIcon > maxIconWidth)
                {
                    [colIcon setHidden: NO];
                    maxIconWidth = widthIcon;
                    [colIcon setWidth: maxIconWidth];
                }
            }
        }
    }
    
    void ListBoxImpl::SetList(const char* list, char separator, char typesep)
    {
        Clear();
        size_t count = strlen(list) + 1;
        std::vector<char> words(list, list+count);
        char* startword = words.data();
        char* numword = NULL;
        int i = 0;
        for (; words[i]; i++)
        {
            if (words[i] == separator)
            {
                words[i] = '\0';
                if (numword)
                    *numword = '\0';
                Append(startword, numword?atoi(numword + 1):-1);
                startword = words.data() + i + 1;
                numword = NULL;
            }
            else if (words[i] == typesep)
            {
                numword = words.data() + i;
            }
        }
        if (startword)
        {
            if (numword)
                *numword = '\0';
            Append(startword, numword?atoi(numword + 1):-1);
        }
        [table reloadData];
    }
    
    int ListBoxImpl::Length()
    {
        return ld.Length();
    }
    
    void ListBoxImpl::Select(int n)
    {
        [table selectRowIndexes:[NSIndexSet indexSetWithIndex:n] byExtendingSelection:NO];
        [table scrollRowToVisible:n];
    }
    
    int ListBoxImpl::GetSelection()
    {
        return static_cast<int>([table selectedRow]);
    }
    
    int ListBoxImpl::Find(const char* prefix)
    {
        int count = Length();
        for (int i = 0; i < count; i++)
        {
            const char* s = ld.GetString(i);
            if (s && (s[0] != '\0') && (0 == strncmp(prefix, s, strlen(prefix))))
            {
                return i;
            }
        }
        return - 1;
    }
    
    void ListBoxImpl::GetValue(int n, char* value, int len)
    {
        const char* textString = ld.GetString(n);
        if (textString == NULL)
        {
            value[0] = '\0';
            return;
        }
        strncpy(value, textString, len);
        value[len - 1] = '\0';
    }
    
    void ListBoxImpl::RegisterImage(int type, const char* xpm_data)
    {
        XPM xpm(xpm_data);
        NSImage* img = ImageFromXPM(&xpm);
        [img retain];
        ImageMap::iterator it=images.find(type);
        if (it == images.end())
        {
            images[type] = img;
        }
        else
        {
            [it->second release];
            it->second = img;
        }
    }
    
    void ListBoxImpl::RegisterRGBAImage(int type, int width, int height, const unsigned char *pixelsImage) {
        CGImageRef imageRef = ImageCreateFromRGBA(width, height, pixelsImage, false);
        NSSize sz = {static_cast<CGFloat>(width), static_cast<CGFloat>(height)};
        NSImage *img = [[[NSImage alloc] initWithSize: sz] autorelease];
        NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithCGImage: imageRef];
        [img addRepresentation: bitmapRep];
        [bitmapRep release];
        CGImageRelease(imageRef);
        [img retain];
        ImageMap::iterator it=images.find(type);
        if (it == images.end())
        {
            images[type] = img;
        }
        else
        {
            [it->second release];
            it->second = img;
        }
    }
    
    void ListBoxImpl::ClearRegisteredImages()
    {
        for (ImageMap::iterator it=images.begin();
             it != images.end(); ++it)
        {
            [it->second release];
            it->second = nil;
        }
        images.clear();
    }
    
    int ListBoxImpl::Rows()
    {
        return ld.Length();
    }
    
    NSImage* ListBoxImpl::ImageForRow(NSInteger row)
    {
        ImageMap::iterator it = images.find(ld.GetType(row));
        if (it != images.end())
        {
            NSImage* img = it->second;
            return img;
        }
        else
        {
            return nil;
        }
    }
    
    NSString* ListBoxImpl::TextForRow(NSInteger row)
    {
        const char* textString = ld.GetString(row);
        NSString* sTitle;
        if (unicodeMode)
            sTitle = @(textString);
        else
            sTitle = [NSString stringWithCString:textString encoding:NSWindowsCP1252StringEncoding];
        return sTitle;
    }
    
    void ListBoxImpl::DoubleClick()
    {
        if (doubleClickAction)
        {
            doubleClickAction(doubleClickActionData);
        }
    }
    
} // unnamed namespace

//----------------- ListBox ------------------------------------------------------------------------

ListBox::ListBox()
{
}

ListBox::~ListBox()
{
}

ListBox* ListBox::Allocate()
{
	ListBoxImpl* lb = new ListBoxImpl();
	return lb;
}
