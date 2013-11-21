

enum {
	OakImageAndTextCellHitImage = (1 << 10),
	OakImageAndTextCellHitText  = (1 << 11),
};

@interface OakImageAndTextCell : NSTextFieldCell

@property (nonatomic, retain) NSImage* image;

- (NSRect)imageFrameWithFrame: (NSRect)aRect
                inControlView: (NSView*)aView;

- (NSRect)textFrameWithFrame: (NSRect)aRect
               inControlView: (NSView*)aView;

@end
