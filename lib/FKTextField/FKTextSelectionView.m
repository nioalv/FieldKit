/*
 
 FKTextSelectionView.m
 FieldKit
 
 Copyright (cc) 2012 Luis Laugga.
 Some rights reserved, all wrongs deserved.
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of
 this software and associated documentation files (the "Software"), to deal in
 the Software without restriction, including without limitation the rights to
 use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 the Software, and to permit persons to whom the Software is furnished to do so,
 subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
*/

#import "FKTextSelectionView.h"
#import "FKTextSelectionView_Internal.h"

#import "FKTextAppearance.h"

@implementation FKTextSelectionView

@synthesize selectionRange = _selectionRange;
@synthesize selectingContainer = _selectingContainer;
@synthesize caretView = _caretView;

#pragma mark -
#pragma mark Initialization

- (void)dealloc
{
    // Clean up
    self.selectingContainer = nil;
    self.caretView = nil;
    
    [super dealloc];
}

- (id)initWithSelectingContainer:(UIView<FKTextSelectingContainer> *)selectingContainer
{
    self = [super initWithFrame:selectingContainer.textContentView.frame];
    if(self)
    {
        // Assign the FKTextSelectingContainer conforming UIView
        self.selectingContainer = selectingContainer;
        
        // Set up view
        self.backgroundColor = [UIColor clearColor];
        
        // Set up state
        _selectionChange = FKTextSelectionChangeNone;
        
        // Set up caret view
        self.caretView = [FKTextCaretView defaultCaretView];
        [self addSubview:_caretView];
        
        _selectionRange = NSMakeRange(0, 0);
    }
    return self;
}

#pragma mark -
#pragma mark Layout (observing changes)

- (void)willMoveToSuperview:(UIView *)superview
{
    [_caretView show];
    
    _visible = YES;
}

- (void)removeFromSuperview
{
    [super removeFromSuperview];
    
    [self hideRange];
    [_caretView hide];
    
    _visible = NO;
}

#pragma mark -
#pragma mark Properties

- (void)setSelectionRange:(NSRange)selectionRange
{
    // Update if different
    if(_selectionRange.location != selectionRange.location || _selectionRange.length != selectionRange.length)
    {
        if(selectionRange.location != NSNotFound)
        {
            // Notify selection will change to container's responder input delegate
            [_selectingContainer.responder.inputDelegate selectionWillChange:_selectingContainer.responder];
            
            // Assign selection range
            _selectionRange = selectionRange;
            
            // Update selection if it's the case
            [self updateSelectionIfNeeded];
            
            // Notify selection did change to container's responder input delegate
            [_selectingContainer.responder.inputDelegate selectionDidChange:_selectingContainer.responder];
        }
    }
}

#pragma mark -
#pragma mark Update

- (void)updateSelectionIfNeeded
{
    if(_selectionRange.length > 0) // going into range
    {
        if(_rangeView == nil) // previous was caret
        {
            [_caretView hide];
            [self showRange];
        }

        [self updateRange];
    }
    else // going into caret
    {
        if(_rangeView != nil) // previous was range
        {
            [self hideRange];
            [_caretView show];
        }

        // Update caret view position
        [_caretView update:[_selectingContainer.textContentView textOffsetRectForIndex:_selectionRange.location]];
    }
}

#pragma mark -
#pragma mark Selection Modifiers

- (void)setCaretSelectionForPoint:(CGPoint)point
{
    // Set selection location based on index closest to point
    NSUInteger index = [_selectingContainer.textContentView textClosestIndexForPoint:point]; // closest index
    self.selectionRange = NSMakeRange(index, 0); // set location
    
    // Touch the caret view
    [_caretView touch];
}

- (void)setWordSelectionForPoint:(CGPoint)point
{
    // Set selection location+length based on word that contains index closest to point
    NSUInteger index = [_selectingContainer.textContentView textClosestIndexForPoint:point]; // closest index
    NSRange range = [_selectingContainer.textContentView textWordRangeForIndex:index]; // word range for closest index
    self.selectionRange = range; // set word range
}

#pragma mark -
#pragma mark Selection change mode

- (BOOL)shouldBeginSelectionChangeForPoint:(CGPoint)point
{
    if(_selectionRange.length > 0)
        return [_rangeView pointCanDrag:point]; // range test
    else
        return [_caretView pointCanDrag:point]; // caret test
}

- (void)beginSelectionChangeForPoint:(CGPoint)point
{
    if(_selectionRange.length > 0) // going into range
    {
        if([_rangeView.startGrabber pointCanDrag:point])
        {
            _selectionChange = FKTextSelectionChangeStartGrabber;
            _selectionChangeBeginPoint = _rangeView.startEdge.origin;
        }
        else
        {
            _selectionChange = FKTextSelectionChangeEndGrabber;
            _selectionChangeBeginPoint = _rangeView.endEdge.origin;
        }
    }
    else
    {
        _selectionChange = FKTextSelectionChangeCaret;
        _selectionChangeBeginPoint = _caretView.frame.origin;

        _caretView.blink = NO;
    }
    
    // Magnifier
    [self showMagnifier];
    [self updateMagnifier:point];
}

- (void)changeSelectionForTranslationPoint:(CGPoint)translationPoint
{
    // Calculate absolute point
    CGPoint point = CGPointMake(_selectionChangeBeginPoint.x+translationPoint.x, _selectionChangeBeginPoint.y+translationPoint.y);
    
    // Set selection location based on index closest to point
    NSUInteger index = [_selectingContainer.textContentView textClosestIndexForPoint:point]; // closest index
    
    if(_selectionChange == FKTextSelectionChangeCaret)
    {
        self.selectionRange = NSMakeRange(index, 0); // set caret location
    }
    else
    {
        if(_selectionChange == FKTextSelectionChangeStartGrabber)
        {
            // start grabber
            NSUInteger end = self.selectionRange.location+self.selectionRange.length;
            NSUInteger loc = index < end ? index : end-1;
            NSUInteger length = end-loc;
            self.selectionRange = NSMakeRange(loc, length); // set word range
            
        }
        else
        {
            // end grabber
            NSUInteger start = self.selectionRange.location;
            NSUInteger loc = start;
            NSUInteger length = index > start ? index-start : 1;
            self.selectionRange = NSMakeRange(loc, length); // set word range
        }
    }
    
    // Magnifier
    [self updateMagnifier:point];
}

- (void)endSelectionChange
{
    if(_selectionChange == FKTextSelectionChangeCaret)
    {
        _caretView.blink = YES;
    }
    
    // Magnifier
    [self hideMagnifier];
    
    _selectionChange = FKTextSelectionChangeNone; // change to none
}

#pragma mark -
#pragma mark Text Modifiers

- (void)insertTextIntoSelection:(NSString *)insertedText
{
    // Create mutable copy
    NSMutableString * mutableText = [_selectingContainer.textContentView.text mutableCopy];
    
    // Create selection change copy
    NSRange updatedSelectionRange = _selectionRange;
    
    // Apply changes
    if (_selectionRange.length > 0)
    {
		// Replace selected text with user-entered text
        [mutableText replaceCharactersInRange:updatedSelectionRange withString:insertedText];
        updatedSelectionRange.length = 0;
        updatedSelectionRange.location += insertedText.length;
    } 
    else 
    {
        // Insert user-entered text at current insertion point
        [mutableText insertString:insertedText atIndex:updatedSelectionRange.location];        
        updatedSelectionRange.location += insertedText.length;
    }
    
    // Notify text will change to container's responder input delegate
    [_selectingContainer.responder.inputDelegate textWillChange:_selectingContainer.responder];
    
    // Update content
    _selectingContainer.textContentView.text = mutableText;
    
    // Update selection
    self.selectionRange = updatedSelectionRange;
    
    // Notify text did change to container's responder input delegate
    [_selectingContainer.responder.inputDelegate textDidChange:_selectingContainer.responder];
    
    // Clean up
    [mutableText release];
}

- (void)deleteTextFromSelection
{
    if(_selectionRange.location == 0 && _selectionRange.length == 0)
        return; // nothing to delete
    
    // Create mutable copy
    NSMutableString * mutableText = [_selectingContainer.textContentView.text mutableCopy];
    
    // Create selection change copy
    NSRange updatedSelectionRange = _selectionRange;
    
    // Apply changes
    if (updatedSelectionRange.length > 0) 
    {
		// Delete the selected text
        [mutableText deleteCharactersInRange:updatedSelectionRange];
        updatedSelectionRange.length = 0;
    } 
    else if (updatedSelectionRange.location > 0) 
    {
		// Delete one char of text at the current insertion point
        updatedSelectionRange.location--;
        updatedSelectionRange.length = 1;
        [mutableText deleteCharactersInRange:updatedSelectionRange];
        updatedSelectionRange.length = 0;
    }
    
    // Notify text will change to container's responder input delegate
    [_selectingContainer.responder.inputDelegate textWillChange:_selectingContainer.responder];
    
    // Update content
    _selectingContainer.textContentView.text = mutableText;
    
    // Update selection
    self.selectionRange = updatedSelectionRange;
    
    // Notify text did change to container's responder input delegate
    [_selectingContainer.responder.inputDelegate textDidChange:_selectingContainer.responder];
    
    // Clean up
    [mutableText release];
}

- (void)replaceTextInRange:(NSRange)replacementRange withText:(NSString *)replacementText
{
    // Check replacementRange location against text boundaries
    if (replacementRange.location > [_selectingContainer.textContentView.text length])
        return;
    
    // Create mutable copy
    NSMutableString * mutableText = [_selectingContainer.textContentView.text mutableCopy];
 
    // Create selection change copy
    NSRange updatedSelectionRange = _selectionRange;
    
    // Check replacementRange length against text boundaries
    if ((replacementRange.location+replacementRange.length) > [mutableText length])
    {
        replacementRange.length = [mutableText length] - replacementRange.location; // range can't extend past text boundaries
    }

    // Determine if replaced range intersects current selection range
	// and update selection range if so.
    if ((replacementRange.location + replacementRange.length) <= updatedSelectionRange.location) // before selection, no overlapping
    {  
        updatedSelectionRange.location -= (replacementRange.length - replacementText.length); // move back _selectionRange location
    } 
    else if (replacementRange.location >= (updatedSelectionRange.location + updatedSelectionRange.length)) // after selection, no overlapping
    {   
        // no need to change _selectionRange, just replace characters as pretended
    }
    else // overlaps selection
    {
        updatedSelectionRange.location = replacementRange.location + replacementText.length; // move forward _selectionRange location just after replacement
        updatedSelectionRange.length = 0; // length = 0
    }
    
    // Now replace characters in text storage
    [mutableText replaceCharactersInRange:replacementRange withString:replacementText];    
    
    // Notify text will change to container's responder input delegate
    [_selectingContainer.responder.inputDelegate textWillChange:_selectingContainer.responder];
    
    // Update content
    _selectingContainer.textContentView.text = mutableText;
    
    // Update selection
    self.selectionRange = updatedSelectionRange;
    
    // Notify text did change to container's responder input delegate
    [_selectingContainer.responder.inputDelegate textDidChange:_selectingContainer.responder];
    
    // Clean up
    [mutableText release];
}

#pragma mark -
#pragma mark Range view

- (void)showRange
{
    if(_rangeView == nil)
    {
        _rangeView = [[FKTextRangeView alloc] initWithFrame:self.bounds];
        [self addSubview:_rangeView];
        [self setNeedsDisplay];
    }
}

- (void)hideRange
{
    if(_rangeView != nil)
    {
        [_rangeView removeFromSuperview];
        [_rangeView release];
        _rangeView = nil;
        [self setNeedsDisplay];
    }
}

- (void)updateRange
{
    if(_rangeView != nil)
    {
        _rangeView.rects = [_selectingContainer.textContentView textRectsForRange:_selectionRange];
    }
}

#pragma mark -
#pragma mark Loupe Magnifier view

- (void)showMagnifier
{
    if(_selectionChange == FKTextSelectionChangeCaret)
    {
        if(_loupeMagnifierView == nil)
        {
            _loupeMagnifierView = [[FKTextLoupeMagnifierView alloc] init];
            UIWindow * window = [[[UIApplication sharedApplication] windows] firstObject];
            if(window)
                [window addSubview:_loupeMagnifierView];
            else
                [self addSubview:_loupeMagnifierView];
            [self setNeedsDisplay];
        }
    }
    else if(_selectionChange == FKTextSelectionChangeStartGrabber || _selectionChange == FKTextSelectionChangeEndGrabber)
    {
        if(_rangeMagnifierView == nil)
        {
            _rangeMagnifierView = [[FKTextRangeMagnifierView alloc] init];
            UIWindow * window = [[[UIApplication sharedApplication] windows] firstObject];
            if(window)
                [window addSubview:_rangeMagnifierView];
            else
                [self addSubview:_rangeMagnifierView];
            [self setNeedsDisplay];
        }
    }
}

- (void)hideMagnifier
{
    if(_selectionChange == FKTextSelectionChangeCaret)
    {
        if(_loupeMagnifierView != nil)
        {
            [_loupeMagnifierView removeFromSuperview];
            [_loupeMagnifierView release];
            _loupeMagnifierView = nil;
            [self setNeedsDisplay];
        }
    }
    else if(_selectionChange == FKTextSelectionChangeStartGrabber || _selectionChange == FKTextSelectionChangeEndGrabber)
    {
        if(_rangeMagnifierView != nil)
        {
            [_rangeMagnifierView removeFromSuperview];
            [_rangeMagnifierView release];
            _rangeMagnifierView = nil;
            [self setNeedsDisplay];
        }
    }
}

- (void)updateMagnifier:(CGPoint)position
{
    if(_selectionChange == FKTextSelectionChangeCaret)
    {
        if(_loupeMagnifierView != nil)
        {
            _loupeMagnifierView.position = position;
        }
    }
    else if(_selectionChange == FKTextSelectionChangeStartGrabber)
    {
        if(_rangeMagnifierView != nil)
        {
            _rangeMagnifierView.position =  _rangeView.startEdge.origin;
        }
    }
    else if(_selectionChange == FKTextSelectionChangeEndGrabber)
    {
        if(_rangeMagnifierView != nil)
        {
            _rangeMagnifierView.position = _rangeView.endEdge.origin;
        }
    }
}

@end
