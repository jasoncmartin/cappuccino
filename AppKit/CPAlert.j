/*
 * CPAlert.j
 * AppKit
 *
 * Created by Jake MacMullin.
 * Copyright 2008, Jake MacMullin.
 *
 * 11/10/2008 Ross Boucher
 *     - Make it conform to style guidelines, general cleanup and ehancements
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

@import <Foundation/CPObject.j>
@import <Foundation/CPString.j>

@import <AppKit/CPApplication.j>
@import <AppKit/CPButton.j>
@import <AppKit/CPColor.j>
@import <AppKit/CPFont.j>
@import <AppKit/CPImage.j>
@import <AppKit/CPImageView.j>
@import <AppKit/CPPanel.j>
@import <AppKit/CPTextField.j>

/*
    @global
    @group CPAlertStyle
*/
CPWarningAlertStyle =        0;
/*
    @global
    @group CPAlertStyle
*/
CPInformationalAlertStyle =  1;
/*
    @global
    @group CPAlertStyle
*/
CPCriticalAlertStyle =       2;


var CPAlertWarningImage,
    CPAlertInformationImage,
    CPAlertErrorImage;

/*!
    @ingroup appkit
    
    CPAlert is an alert panel that can be displayed modally to present the
    user with a message and one or more options.

    It can be used to display an information message \c CPInformationalAlertStyle,
    a warning message \c CPWarningAlertStyle (the default), or a critical
    alert \c CPCriticalAlertStyle. In each case the user can be presented with one
    or more options by adding buttons using the \c -addButtonWithTitle: method.

    The panel is displayed modally by calling \c -runModal and once the user has
    dismissed the panel, a message will be sent to the panel's delegate (if set), informing
    it which button was clicked (see delegate methods).

    The panel can also be displayed as a sheet by calling
    \c -beginSheetModalForWindow:modalDelegate:didEndSelector:contextInof: and once the user has
    dismissed the panel, a message will be sent to the passed modal delegate, informing
    it which button was clicked by means of the passed selector. The \c didEndSelector should be
    in the format
    \c -(void)didEnd:(CPAlert)theAlert returnCore:(int)returnCode contextInfo:(id)contextInfo.

    @delegate -(void)alertDidEnd:(CPAlert)theAlert returnCode:(int)returnCode;
    Called when the user dismisses the alert by clicking one of the buttons.
    @param theAlert the alert panel that the user dismissed
    @param returnCode the index of the button that the user clicked (starting from 0, 
           representing the first button added to the alert which appears on the
           right, 1 representing the next button to the left and so on)
*/
@implementation CPAlert : CPObject
{
    CPPanel         _alertPanel;

    CPTextField     _messageLabel;
    CPTextField     _informativeLabel;
    CPImageView     _alertImageView;

    CPAlertStyle    _alertStyle;
    CPString        _windowTitle;
    int             _windowStyle;
    int             _buttonCount;
    CPArray         _buttons;

    id              _modalDelegate;
	SEL				_modalSelector;
}

+ (void)initialize
{
    if (self != CPAlert)
        return;

    var bundle = [CPBundle bundleForClass:[self class]];   

    CPAlertWarningImage     = [[CPImage alloc] initWithContentsOfFile:[bundle pathForResource:@"CPAlert/dialog-warning.png"] 
                                                                 size:CGSizeMake(32.0, 32.0)];
                                                             
    CPAlertInformationImage = [[CPImage alloc] initWithContentsOfFile:[bundle pathForResource:@"CPAlert/dialog-information.png"] 
                                                                 size:CGSizeMake(32.0, 32.0)];
                                                                 
    CPAlertErrorImage       = [[CPImage alloc] initWithContentsOfFile:[bundle pathForResource:@"CPAlert/dialog-error.png"] 
                                                                 size:CGSizeMake(32.0, 32.0)];
}

/*!
    Initializes a \c CPAlert panel with the default alert style \c CPWarningAlertStyle.
*/
- (id)init
{
    if (self = [super init])
    {
        _buttonCount = 0;
        _buttons = [CPArray array];
        _alertStyle = CPWarningAlertStyle;

        [self setWindowStyle:nil];
    }
    
    return self;
}

/*!
    Sets the window appearance.
    @param styleMask - Either CPHUDBackgroundWindowMask or nil for standard.
*/
- (void)setWindowStyle:(int)styleMask
{
    _windowStyle = styleMask;
    
    _alertPanel = [[CPPanel alloc] initWithContentRect:CGRectMake(0.0, 0.0, 400.0, 110.0) styleMask:(styleMask ? styleMask | CPTitledWindowMask : CPTitledWindowMask) | CPDocModalWindowMask];
    [_alertPanel setFloatingPanel:YES];
    [_alertPanel center];

    var count = [_buttons count];
    for(var i=0; i < count; i++)
    {
        var button = _buttons[i];
        [button setTheme:(_windowStyle === CPHUDBackgroundWindowMask) ? [CPTheme themeNamed:"Aristo-HUD"] : [CPTheme defaultTheme]];

        [[_alertPanel contentView] addSubview:button];
    }

    [self _layoutButtons];

    if (!_messageLabel)
    {
        _messageLabel = [[CPTextField alloc] initWithFrame:CGRectMakeZero()];
        [_messageLabel setFont:[CPFont boldSystemFontOfSize:13.0]];
        [_messageLabel setLineBreakMode:CPLineBreakByWordWrapping];
        [_messageLabel setAlignment:CPJustifiedTextAlignment];
        [_messageLabel setAutoresizingMask:CPViewWidthSizable|CPViewHeightSizable];


        _alertImageView = [[CPImageView alloc] initWithFrame:CGRectMake(15.0, 12.0, 32.0, 32.0)];

        _informativeLabel = [[CPTextField alloc] initWithFrame:CGRectMakeZero()];
        [_informativeLabel setFont:[CPFont systemFontOfSize:12.0]];
        [_informativeLabel setLineBreakMode:CPLineBreakByWordWrapping];
        [_informativeLabel setAlignment:CPJustifiedTextAlignment];
        [_informativeLabel setAutoresizingMask:CPViewWidthSizable|CPViewHeightSizable];
    }
    [_messageLabel setTextColor:(styleMask & CPHUDBackgroundWindowMask) ? [CPColor whiteColor] : [CPColor blackColor]];
    [_informativeLabel setTextColor:(styleMask & CPHUDBackgroundWindowMask) ? [CPColor whiteColor] : [CPColor blackColor]];

    [[_alertPanel contentView] addSubview:_messageLabel];
    [[_alertPanel contentView] addSubview:_alertImageView];
    [[_alertPanel contentView] addSubview:_informativeLabel];

    [self _layoutMessage];
}

/*!
    Sets the window's title. If this is not defined, a default title based on your warning level will be used.
    @param aTitle the title to use in place of the default. Set to nil to use default.
*/
- (void)setTitle:(CPString)aTitle
{
    _windowTitle = aTitle;
}

/*!
    Gets the window's title.
*/
- (CPString)title
{
    return _windowTitle;
}

/*!
    Gets the window's style.
*/
- (int)windowStyle
{
    return _windowStyle;
}

/*!
    Sets the receiver’s delegate.
    @param delegate - Delegate for the alert. nil removes the delegate.
*/
- (void)setDelegate:(id)delegate
{
    _delegate = delegate;
}

/*!
    Gets the receiver's delegate.
*/
- (void)delegate
{
    return _delegate;
}

/*!
    Sets the alert style of the receiver.
    @param style - Alert style for the alert.
*/
- (void)setAlertStyle:(CPAlertStyle)style
{
    _alertStyle = style;
}

/*!
    Gets the alert style.
*/
- (CPAlertStyle)alertStyle
{
    return _alertStyle;
}

/*!
    Sets the receiver’s message text, or title, to a given text.
    @param messageText - Message text for the alert.
*/
- (void)setMessageText:(CPString)messageText
{
    [_messageLabel setStringValue:messageText];
    [self _layoutMessage];
}

/*!
    Returns the receiver's message text body.
*/
- (CPString)messageText
{
    return [_messageLabel stringValue];
}

/*!
    Sets the receiver's informative text, shown below the message text.
    @param informativeText - The informative text.
*/
- (void)setInformativeText:(CPString)informativeText
{
    [_informativeLabel setStringValue:informativeText];
    // No need to call _layoutMessage - only the length of the messageText
    // can affect anything there.
}

/*!
    Returns the receiver's informative text.
*/
- (CPString)informativeText
{
    return [_informativeLabel stringValue];
}

/*!
    Adds a button with a given title to the receiver.
    Buttons will be added starting from the right hand side of the \c CPAlert panel.
    The first button will have the index 0, the second button 1 and so on.

    The first button will automatically be given a key equivalent of Return,
    and any button titled "Cancel" will be given a key equivalent of Escape.

    You really shouldn't need more than 3 buttons.
*/
- (void)addButtonWithTitle:(CPString)title
{
    var bounds = [[_alertPanel contentView] bounds],
        button = [[CPButton alloc] initWithFrame:CGRectMakeZero()];

    [button setTitle:title];
    [button setTarget:self];
    [button setTag:_buttonCount];
    [button setAction:@selector(_notifyDelegate:)];
    
    [button setTheme:(_windowStyle & CPHUDBackgroundWindowMask) ? [CPTheme themeNamed:"Aristo-HUD"] : [CPTheme defaultTheme]];
    [button setAutoresizingMask:CPViewMinXMargin | CPViewMinYMargin];

    [[_alertPanel contentView] addSubview:button];
    
    if (_buttonCount == 0)
        [button setKeyEquivalent:CPCarriageReturnCharacter];
    else if ([title lowercaseString] === "cancel")
        [button setKeyEquivalent:CPEscapeFunctionKey];
    else
        [button setKeyEquivalent:nil];

    _buttonCount++;
    [_buttons addObject:button];

    [self _layoutButtons];
}

- (void)_layoutButtons
{
    var bounds = [[_alertPanel contentView] bounds],
        count = [_buttons count],
        offsetX = CGRectGetWidth(bounds),
        offsetY = CGRectGetHeight(bounds) - 34.0;
    for(var i=0; i < count; i++)
    {
        var button = _buttons[i];

        [button sizeToFit];
        var buttonBounds = [button bounds],
            width = MAX(80.0, CGRectGetWidth(buttonBounds)),
            height = CGRectGetHeight(buttonBounds);
        offsetX -= (width + 10);
        [button setFrame:CGRectMake(offsetX, offsetY, width, height)];
    }
}

- (void)_layoutMessage
{
    var bounds = [[_alertPanel contentView] bounds],
        width = CGRectGetWidth(bounds) - 73.0,
        size = [([_messageLabel stringValue] || " ") sizeWithFont:[_messageLabel currentValueForThemeAttribute:@"font"] inWidth:width],
        contentInset = [_messageLabel currentValueForThemeAttribute:@"content-inset"],
        height = size.height + contentInset.top + contentInset.bottom;

    [_messageLabel setFrame:CGRectMake(57.0, 10.0, width, height)];

    [_informativeLabel setFrame:CGRectMake(57.0, 10.0 + height + 6.0, width, CGRectGetHeight(bounds) - height - 50.0)];
}

/*!
    Displays the \c CPAlert panel as a modal dialog. The user will not be
    able to interact with any other controls until s/he has dismissed the alert
    by clicking on one of the buttons.
*/
- (void)runModal
{
    var theTitle;
    
    switch (_alertStyle)
    {
        case CPWarningAlertStyle:       [_alertImageView setImage:CPAlertWarningImage];
                                        theTitle = @"Warning";
                                        break;
        case CPInformationalAlertStyle: [_alertImageView setImage:CPAlertInformationImage];
                                        theTitle = @"Information";
                                        break;
        case CPCriticalAlertStyle:      [_alertImageView setImage:CPAlertErrorImage];
                                        theTitle = @"Error";
                                        break;
    }
    
    [_alertPanel setTitle:_windowTitle ? _windowTitle : theTitle];
    
    [CPApp runModalForWindow:_alertPanel];
}

/*!
    Displays the \c CPAlert panel as a modal sheet. The user will not be
    able to interact with any other controls until s/he has dismissed the alert
    by clicking on one of the buttons.
*/
- (void)beginSheetModalForWindow:(CPWindow)aWindow modalDelegate:(id)aDel didEndSelector:(SEL)aSelector contextInfo:(id)aInfo {
	_modalDelegate = aDel;
	_modalSelector = aSelector;
	
	var theTitle;
	
	switch(_alertStyle) {
		case CPWarningAlertStyle:		[_alertImageView setImage:CPAlertWarningImage];
										theTitle = @"Warning";
										break;
		case CPInformationalAlertStyle:	[_alertImageView setImage:CPAlertInformationImage];
										theTitle = @"Information";
										break;
		case CPCriticalAlertStyle:		[_alertImageView setImage:CPAlertErrorImage];
										theTitle = @"Error";
										break;
	}
	
	[_alertPanel setTitle:_windowTitle ? _windowTitle : theTitle];
	
	[CPApp beginSheet:_alertPanel modalForWindow:aWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:aInfo];
}

/* @ignore */
- (void)sheetDidEnd:(CPWindow)sheet returnCode:(int)returnCode contextInfo:(id)contextInfo {
	if(_selector && _delegate) {
		var imp = [_delegate methodForSelector:_selector];
		
		imp(_delegate, _selector, self, returnCode, contextInfo);
	}
	
	[_alertPanel close];
}

/* @ignore */
- (void)_notifyDelegate:(id)button
{
	if([_alertPanel isSheet]) {
	    [CPApp abortModal];
	    [_alertPanel close];
	
	    if (_delegate && [_delegate respondsToSelector:@selector(alertDidEnd:returnCode:)])
	        [_delegate alertDidEnd:self returnCode:[button tag]];
	} else {
		[CPApp endSheet:_alertPanel returnCode:[button tag]];
	}
}

@end
