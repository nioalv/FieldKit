//
//  LATextField_Internal.h
//  LauggaKit
//
//  Created by Luis Laugga on 9/19/12.
//  Copyright (c) 2012 Luis Laugga. All rights reserved.
//

#import "LATextField.h"
#import "LATextSelecting.h"

#import "LATextSelectionView.h"
#import "LATextInteractionAssistant.h"

#pragma mark -
#pragma mark LATextField internal class extension

/*!
 @category LATextField internal extension
 */
@interface LATextField () <LATextSelectingContainer>

@property(nonatomic, readwrite) BOOL editing;

@end

