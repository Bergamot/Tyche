//
//  GameRenderer.m
//  OpenGLTest
//
//  Created by Joel Bernstein on 9/24/09.
//  Copyright Joel Bernstein 2009. All rights reserved.
//

#import "GameRenderer.h"
#import "AnimatedFloat.h"
#import "AnimatedVector3D.h"
#import "TextController.h"
#import "GLMenu.h"
#import "GLCard.h"
#import "GLTable.h"
#import "GLSplash.h"
#import "MenuController.h"
#import "MenuLayerController.h"
#import "GLCardGroup.h"
#import "GLChipGroup.h"
#import "GLChip.h"
#import "GLLabel.h"
#import "AppController.h"
#import "SoundController.h"
#import "GameController.h"
#import "GameControllerSP.h"
#import "GameControllerMP.h"
#import "GLTexture.h"
#import "CameraController.h"
#import "TextControllerMainMenu.h"
#import "TextControllerCredits.h"
#import "TextControllerActions.h"
#import "TextControllerStatusBar.h"
#import "TextControllerServerInfo.h"
#import "TextureController.h"
#import "MenuControllerJoinGame.h"
#import "MenuControllerMain.h"

@implementation GameRenderer

@synthesize animated = _animated;

@synthesize gameController      = _gameController;
@synthesize appController       = _appController;
@synthesize soundController     = _soundController;
@synthesize touchedObjects      = _touchedObjects;
@synthesize touchedLocations    = _touchedLocations;
@synthesize menuLayerController = _menuLayerController;
@synthesize chipGroup           = _chipGroup;
@synthesize cardGroup           = _cardGroup;
@synthesize table               = _table;
@synthesize splash              = _splash;
@synthesize textControllers     = _textControllers;
@synthesize camera              = _camera;
@synthesize creditLabel         = _creditLabel;
@synthesize betLabel            = _betLabel;
@synthesize betItems            = _betItems;
@synthesize lightness           = _lightness;

-(id)init
{
    self = [super init];
    
	if(self)
	{
		_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
        
        if(!_context || ![EAGLContext setCurrentContext:_context]) { [self release]; return nil; }
		
		// Create default framebuffer object. The backing will be allocated for the current layer in -resizeFromLayer
		glGenFramebuffersOES(1, &_defaultFramebuffer);
		glGenRenderbuffersOES(1, &_colorRenderbuffer);
		glBindFramebufferOES(GL_FRAMEBUFFER_OES, _defaultFramebuffer);
		glBindRenderbufferOES(GL_RENDERBUFFER_OES, _colorRenderbuffer);
		glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, _colorRenderbuffer);
        
        self.animated = YES;
        self.lightness = [AnimatedFloat withValue:1];
    }
	
	return self;
}

-(BOOL)resizeFromLayer:(CAEAGLLayer*)layer
{	
	// Allocate color buffer backing based on the current layer size
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, _colorRenderbuffer);
    [_context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:layer];
	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &_backingWidth);
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &_backingHeight);
	
    if (glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES)
	{
		NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES));
        return NO;
    }
        
    [self load];
    
    return YES;
}

-(void)load
{
    self.animated = NO;
    
    //setup code:
        
    self.camera = [[[CameraController alloc] init] autorelease];
    
    self.camera.renderer = self;
    
    glDisable(GL_DEPTH_TEST);
    
    glEnable(GL_LIGHTING);
    glEnable(GL_LIGHT0);
    glEnable(GL_CULL_FACE);
    glEnable(GL_COLOR_MATERIAL);
    glEnable(GL_BLEND);                            

    glActiveTexture(GL_TEXTURE0);
	glEnable(GL_TEXTURE_2D);

	glActiveTexture(GL_TEXTURE1);
	glEnable(GL_TEXTURE_2D);

    glActiveTexture(GL_TEXTURE0);
    
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_NORMAL_ARRAY);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    
    GLfloat light0diffuse[] = {0.80, 0.80, 0.80, 1.0}; 
    
    glLightfv(GL_LIGHT0, GL_DIFFUSE, light0diffuse);
    
    glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST); 
    
    glClearColor(0.0, 0.0, 0.0, 1.0);
    
    self.cardGroup        = [[[GLCardGroup         alloc] init] autorelease]; 
    self.splash           = [[[GLSplash            alloc] init] autorelease]; 
    self.table            = [[[GLTable             alloc] init] autorelease]; 
    self.chipGroup        = [[[GLChipGroup         alloc] init] autorelease];
    self.touchedObjects   = [[[NSMutableDictionary alloc] init] autorelease];
    self.touchedLocations = [[[NSMutableDictionary alloc] init] autorelease];
    self.textControllers  = [[[NSMutableDictionary alloc] init] autorelease];
    
    self.menuLayerController = [[[MenuLayerController alloc] init] autorelease];
    
    self.menuLayerController.renderer = self;
    
    [TextureController setTexture:[[[GLTexture alloc] initWithImageFile:@"lightmap.png" ] autorelease] forKey:@"lightmap"];
    [TextureController setTexture:[[[GLTexture alloc] initWithImageFile:@"chips3.png"   ] autorelease] forKey:@"chips"];
    [TextureController setTexture:[[[GLTexture alloc] initWithImageFile:@"cards2.png"   ] autorelease] forKey:@"cards"];
    [TextureController setTexture:[[[GLTexture alloc] initWithPVRTCFile:@"felt3.pvr4"   ] autorelease] forKey:@"table"];
    [TextureController setTexture:[[[GLTexture alloc] initWithImageFile:@"Default.png"  ] autorelease] forKey:@"splash"];
    [TextureController setTexture:[[[GLTexture alloc] initWithPVRTCFile:@"heartsflat.pvr4"  ] autorelease] forKey:@"suit0"];
    [TextureController setTexture:[[[GLTexture alloc] initWithPVRTCFile:@"diamondsflat.pvr4"] autorelease] forKey:@"suit1"];
    [TextureController setTexture:[[[GLTexture alloc] initWithPVRTCFile:@"clubsflat.pvr4"   ] autorelease] forKey:@"suit2"];
    [TextureController setTexture:[[[GLTexture alloc] initWithPVRTCFile:@"spadesflat.pvr4"  ] autorelease] forKey:@"suit3"];
    
    UIFont* font = [UIFont fontWithName:@"Helvetica-Bold" size:30.0];
    
    [TextureController setTexture:[[[GLTexture alloc] initWithString:@"HOLD" dimensions:[@"HOLD" sizeWithFont:font] alignment:UITextAlignmentCenter font:font] autorelease] forKey:@"hold"];
    [TextureController setTexture:[[[GLTexture alloc] initWithString:@"DRAW" dimensions:[@"DRAW" sizeWithFont:font] alignment:UITextAlignmentCenter font:font] autorelease] forKey:@"draw"];
    [TextureController setTexture:[[[GLTexture alloc] initWithButtonOpacity:0.25] autorelease] forKey:@"borderNormal"];
    [TextureController setTexture:[[[GLTexture alloc] initWithButtonOpacity:0.70] autorelease] forKey:@"borderTouched"];
    
    self.cardGroup.renderer = self;
    self.splash.renderer = self;
    self.table.renderer = self;
    
//    { 
//        GLMenu* menu  = [[[GLMenu alloc] init] autorelease]; 
//        
//        menu.textController = [[[TextControllerMainMenu alloc] init] autorelease];
//        
//        menu.textController.center = NO;
//        menu.textController.opacity = 1;
//        
//        menu.renderer = self;
//        menu.textController.renderer = self;
//        
//        menu.location.value = Vector3DMake(30, 0, 0); 
//        menu.texture = self.cardGroup.textureDiamonds;
//    
//        srand48(time(NULL));
//                
//        menu.angleJitter = randomFloat(-10.0, 10.0);
//                
//        [self.menus setObject:menu forKey:@"main"];
//    }
    
    NSMutableArray* servers = [[[NSMutableArray alloc] init] autorelease];
                                
    [servers addObject:@"☃Joel's iPhone"];                           
    [servers addObject:@"☝Rachel's iPod"];                           
    [servers addObject:@"♜Carolyn's iPhone"];                           
    [servers addObject:@"☠John's iPod"];                           
    [servers addObject:@"Sarah's iPhone"];                           
    [servers addObject:@"♘Michele's iPod"];                           
    [servers addObject:@"☂Bonnie's iPhone"];                           
    [servers addObject:@"♂Charles's iPod"];    

    srand48(time(NULL));

    {
        MenuControllerMain* layer = [[[MenuControllerMain alloc] initWithRenderer:self] autorelease];
        
        [self.menuLayerController addMenuLayer:layer forKey:@"0"];
    }
    
    for(int i = 0; i < 2; i++)
    {        
        MenuControllerJoinGame* layer = [[[MenuControllerJoinGame alloc] initWithRenderer:self] autorelease];
        
        for(NSString* server in servers)
        { 
            [layer addServerWithPeerId:server name:server];
        }
        
        [self.menuLayerController addMenuLayer:layer forKey:[NSString stringWithFormat:@"%d", i + 1]];
    }
    
    [self.menuLayerController setKey:@"0"];
    
    { GLChip* chip = [[[GLChip alloc] initWithChipNumber:0] autorelease]; chip.renderer = self; [self.chipGroup.chips setObject:chip forKey:@"1"]; }
    { GLChip* chip = [[[GLChip alloc] initWithChipNumber:1] autorelease]; chip.renderer = self; [self.chipGroup.chips setObject:chip forKey:@"5"]; }
    { GLChip* chip = [[[GLChip alloc] initWithChipNumber:2] autorelease]; chip.renderer = self; [self.chipGroup.chips setObject:chip forKey:@"10"]; }
    { GLChip* chip = [[[GLChip alloc] initWithChipNumber:3] autorelease]; chip.renderer = self; [self.chipGroup.chips setObject:chip forKey:@"25"]; }
    { GLChip* chip = [[[GLChip alloc] initWithChipNumber:4] autorelease]; chip.renderer = self; [self.chipGroup.chips setObject:chip forKey:@"100"]; }
    { GLChip* chip = [[[GLChip alloc] initWithChipNumber:5] autorelease]; chip.renderer = self; [self.chipGroup.chips setObject:chip forKey:@"500"]; }
    { GLChip* chip = [[[GLChip alloc] initWithChipNumber:6] autorelease]; chip.renderer = self; [self.chipGroup.chips setObject:chip forKey:@"1000"]; }
    { GLChip* chip = [[[GLChip alloc] initWithChipNumber:7] autorelease]; chip.renderer = self; [self.chipGroup.chips setObject:chip forKey:@"2500"]; }
    { GLChip* chip = [[[GLChip alloc] initWithChipNumber:8] autorelease]; chip.renderer = self; [self.chipGroup.chips setObject:chip forKey:@"10000"]; }
    
    {
        TextControllerCredits* textController = [[[TextControllerCredits alloc] init] autorelease];
        
        textController.renderer = self;
        
        textController.location = Vector3DMake(5.25, 0, 0);
        
        textController.creditTotal = 235;
        textController.betTotal = 35;
                    
        [textController update];
        
        [self.textControllers setObject:textController forKey:@"credits"];
    }
    
    {
        TextControllerActions* textController = [[[TextControllerActions alloc] init] autorelease];
        
        textController.renderer = self;
        
        textController.location = Vector3DMake(-5.25, 0, 0);
        
        [self.textControllers setObject:textController forKey:@"actions"];
    }
    
    {
        TextControllerStatusBar* textController = [[[TextControllerStatusBar alloc] init] autorelease];
                
        textController.renderer = self;
        
        textController.location = Vector3DMake(0, 0, -7); //-6.4
        
        [self.textControllers setObject:textController forKey:@"status1"];
    }

    {
        TextControllerStatusBar* textController = [[[TextControllerStatusBar alloc] init] autorelease];
                
        textController.renderer = self;
        
        textController.location = Vector3DMake(0, 0, -5.2); //-6.4
        
        textController.anglePitch = -90;
        
        [self.textControllers setObject:textController forKey:@"status2"];
    }
    
    GLfloat zNear       =   0.001;
    GLfloat zFar        = 500.00;
    GLfloat fieldOfView =  30.00; 
    GLfloat size        = zNear * tanf(DEGREES_TO_RADIANS(fieldOfView) / 2.0);
    
    CGRect rect = CGRectMake(0, 0, _backingWidth, _backingHeight); 
    
    glMatrixMode(GL_PROJECTION); 
    
    glFrustumf(-size, size, -size / (rect.size.width / rect.size.height), size / (rect.size.width / rect.size.height), zNear, zFar); 
    
    glViewport(0, 0, rect.size.width, rect.size.height);  
    
    glMatrixMode(GL_MODELVIEW);
        
    glLoadIdentity();
                
    [[UIAccelerometer sharedAccelerometer] setUpdateInterval:(1.0 / 30.0)];
    [[UIAccelerometer sharedAccelerometer] setDelegate:self];
    
    self.splash.opacity = [AnimatedFloat withStartValue:self.splash.opacity.value endValue:0 forTime:2];
    
    self.gameController = [GameController loadWithRenderer:self];
    
    if(!self.gameController) { [self showMenus]; }
    
    self.animated = YES;
}

-(void)draw
{
    static BOOL hasRendered = NO;

    TRANSACTION_BEGIN
    {
        GLfloat cameraPitch = self.camera.pitchAngle.value * self.camera.pitchFactor.value;
        
        glClear(GL_COLOR_BUFFER_BIT);
        
        glRotatef(self.camera.rollAngle.value, 0.0f, 0.0f, 1.0f);   
        
        gluLookAt(self.camera.position.value.x, self.camera.position.value.y, self.camera.position.value.z, self.camera.lookAt.value.x, self.camera.lookAt.value.y, self.camera.lookAt.value.z, 0.0, 1.0, 0.0);
        
        glRotatef(cameraPitch + 90, 1.0f, 0.0f, 0.0f);            
        
        [self.cardGroup resetCardsWithBendFactor:cameraPitch / 90.0];
                
        glTranslatef(0, 0, 3.0 * cameraPitch / 90.0);
        
        self.table.drawStatus = GLTableDrawStatusDiffuse; [self.table draw];                                            
        
        [self.cardGroup drawShadows];                                                              
        [self.chipGroup drawShadows];
        
        self.table.drawStatus = GLTableDrawStatusAmbient; [self.table draw];                                              
    
        { TextController* textController = [self.textControllers objectForKey:@"credits"]; textController.opacity = 1.0/* - (cameraPitch / 90.0)*/; [textController draw]; }
        { TextController* textController = [self.textControllers objectForKey:@"actions"]; textController.opacity = 1.0/* - (cameraPitch / 90.0)*/; [textController draw]; }
        { TextController* textController = [self.textControllers objectForKey:@"status1"]; textController.opacity = 1.0/* - (cameraPitch / 90.0)*/; [textController draw]; }
        
        self.chipGroup.markerOpacity = clipFloat(1.0 - cameraPitch / 90.0,  0, 1); 
        [self.chipGroup drawMarkers];         
        
        self.chipGroup.opacity = clipFloat(-0.04 * cameraPitch + 3.4, 0, 1);
        [self.chipGroup drawChips];
        
        [self.cardGroup drawBacks]; 
        [self.cardGroup drawFronts];
        [self.cardGroup drawLabels];
        
        { TextController* textController = [self.textControllers objectForKey:@"status2"]; textController.opacity = cameraPitch / 45 - 1; [textController draw]; }
        
        [self.menuLayerController draw];
    }
    TRANSACTION_END;
    
    [self.splash draw];
       
    hasRendered = YES;

    [_context presentRenderbuffer:GL_RENDERBUFFER_OES];

    TinyProfilerLog();
}

-(void)showMenus
{   
    [self.camera setMenuVisible:YES];
    
    if(self.animated) 
    {
        self.menuLayerController.hidden = [AnimatedFloat withStartValue:self.menuLayerController.hidden.value endValue:0 speed: 1];
        self.menuLayerController.hidden.curve = AnimationEaseInOut;
        
        self.lightness = [AnimatedFloat withStartValue:self.lightness.value endValue:0.4 forTime:1];
        self.lightness.curve = AnimationEaseInOut;
    }
    else 
    {
        self.menuLayerController.hidden.value = 0; 
        self.lightness.value = 0.4;
    }
}

-(void)hideMenus
{    
    [self.camera setMenuVisible:NO];
    
    if(self.animated) 
    {
        self.menuLayerController.hidden = [AnimatedFloat withStartValue:self.menuLayerController.hidden.value endValue:1 speed: 1]; 
        self.menuLayerController.hidden.curve = AnimationEaseInOut;
        
        self.lightness = [AnimatedFloat withStartValue:self.lightness.value endValue:1 forTime:1];
        self.lightness.curve = AnimationEaseInOut;
    }
    else 
    {
        self.menuLayerController.hidden.value = 1; 
        self.lightness.value = 1;
    }    
}

-(void)flipCardsAndThen:(simpleBlock)work
{
    int cardCount = self.cardGroup.cards.count;

    self.camera.status = CameraStatusCardsFlipped;
    
    for(int i = 0; i < cardCount; i++)
    {
        GLCard* card = [self.cardGroup.cards objectAtIndex:i];
        
        card.location  = [AnimatedVector3D withStartValue:card.location.value  endValue:Vector3DMake(-4 * i + 8,   0,   0) forTime:1];
        card.angleFlip = [AnimatedFloat    withStartValue:card.angleFlip.value endValue:180                                forTime:1];
        
        card.location.curve = AnimationEaseInOut;
        card.angleFlip.curve = AnimationEaseInOut;
        
        if(i == 0) { card.angleFlip.onEnd = work; }
    }
}

-(void)unflipCardsAndThen:(simpleBlock)work
{
    int cardCount = self.cardGroup.cards.count;

    self.camera.status = CameraStatusNormal;
    
    for(int i = 0; i < cardCount; i++)
    {
        GLCard* card = [self.cardGroup.cards objectAtIndex:i];
        
        card.location  = [AnimatedVector3D withStartValue:card.location.value  endValue:Vector3DMake(0,   0,   0) forTime:1];
        card.angleFlip = [AnimatedFloat    withStartValue:card.angleFlip.value endValue:0                         forTime:1];
        
        card.location.curve = AnimationEaseInOut;
        card.angleFlip.curve = AnimationEaseInOut;
        
        if(i == 0) { card.angleFlip.onEnd = work; }
    }
}

-(void)labelTouchedWithKey:(NSString*)key
{
    [self.appController  labelTouchedWithKey:key];
    [self.gameController labelTouchedWithKey:key];
}

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return NO;
}

-(void)accelerometer:(UIAccelerometer*)accelerometer didAccelerate:(UIAcceleration*)acceleration
{        
    static BOOL isUpright = NO;
    
    if(acceleration.x > -0.4 && acceleration.x <  0.4 && acceleration.y > -1.4 && acceleration.y < -0.6)
    {
        if(!isUpright)
        {
            isUpright = YES;
            
            [self showMenus];
            
            //NSLog(@"Orientation Upright!");
        }
    }
    else if(acceleration.x > -0.6 && acceleration.x < 0.6 && acceleration.y > -1.6 && acceleration.y < -0.4)
    {
        // DO NOTHING
    }
    else
    {
        if(isUpright)
        {
            isUpright = NO;
            
            if(self.gameController) { [self hideMenus]; }
            
            //NSLog(@"Orientation Not Upright!");
        }
        
        if(self.camera.isAutomatic)
        {
            GLfloat rawAngle = atan2f(-acceleration.x, -acceleration.z);
            GLfloat angle;
            
            GLfloat clampLow  = 0.5 / 8.0 * M_PI; 
            GLfloat clampHigh = 2.5 / 8.0 * M_PI;
            
            if(rawAngle < clampLow)
            {
                angle = 0;
            }
            else if(rawAngle > clampHigh)
            {
                angle = 90;
            }
            else
            {
                angle = (rawAngle - clampLow) / (clampHigh - clampLow) * 90.0;
            }
            
            self.camera.pitchAngle.value = angle * 0.10 + self.camera.pitchAngle.value * 0.90;
        }
    }
}

-(void)touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event
{   
    TRANSACTION_BEGIN
    {
        glRotatef(self.camera.rollAngle.value, 0.0f, 0.0f, 1.0f);   
        
        gluLookAt(self.camera.position.value.x, self.camera.position.value.y, self.camera.position.value.z, 
                  self.camera.lookAt.value.x,   self.camera.lookAt.value.y,   self.camera.lookAt.value.z, 
                  0.0,                         1.0,                         0.0);
        
        GLfloat angle = self.camera.pitchAngle.value * self.camera.pitchFactor.value;
        
        glRotatef(90,    1, 0, 0);  
        glRotatef(angle, 1, 0, 0);         
        
        for(UITouch* touch in touches) 
        {
            id<Touchable> object = nil;
            
            if(angle < 60)
            {
                for(TextController* textController in self.textControllers.objectEnumerator) { object = [textController testTouch:touch withPreviousObject:object]; }

                for(GLChip* chip in self.chipGroup.chips.objectEnumerator) { object = [chip testTouch:touch withPreviousObject:object]; }
                
                for(GLCard* card in self.cardGroup.cards.reverseObjectEnumerator) { object = [card testTouch:touch withPreviousObject:object]; }
            
                object = [self.menuLayerController testTouch:touch withPreviousObject:object]; 
            }
            else
            {
                for(GLCard* card in self.cardGroup.cards) { object = [card testTouch:touch withPreviousObject:object]; }
            }
            
            if(object)
            {            
                NSValue* key = [NSValue valueWithPointer:touch];
                
                [object handleTouchDown:touch fromPoint:[touch locationInView:touch.view]];
                
                [self.touchedObjects setObject:object forKey:key];
                [self.touchedLocations setObject:[NSValue valueWithCGPoint:[touch locationInView:touch.view]] forKey:[NSValue valueWithPointer:touch]];
            }
            else
            {    
                [self.gameController emptySpaceTouched];
            }
        }
    }
    TRANSACTION_END
}

-(void)touchesMoved:(NSSet*)touches withEvent:(UIEvent*)event
{    
    for(UITouch* touch in touches) 
    {
        NSValue* key = [NSValue valueWithPointer:touch];
        
        NSValue* location = [self.touchedLocations objectForKey:key];
        
        id<Touchable> object = [self.touchedObjects objectForKey:key];
        
        if(object)
        {
            CGPoint pointFrom = [location CGPointValue];
            CGPoint pointTo   = [touch locationInView:touch.view];
            
            [object handleTouchMoved:touch fromPoint:pointFrom toPoint:pointTo];
        }
    }   
}

-(void)touchesEnded:(NSSet*)touches withEvent:(UIEvent*)event
{   
    for(UITouch* touch in touches) 
    {
        NSValue* key = [NSValue valueWithPointer:touch];
        
        NSValue* location = [self.touchedLocations objectForKey:key];
        
        id<Touchable> object = [self.touchedObjects objectForKey:key];
        
        if(object)
        {
            CGPoint pointFrom = [location CGPointValue];
            CGPoint pointTo   = [touch locationInView:touch.view];
            
            [object handleTouchUp:touch fromPoint:pointFrom toPoint:pointTo];
            
            [self.touchedLocations removeObjectForKey:key];        
            [self.touchedObjects removeObjectForKey:key];
        }
    }
}

-(void)dealloc
{
	// Tear down GL
	if(_defaultFramebuffer)
	{
		glDeleteFramebuffersOES(1, &_defaultFramebuffer);
		_defaultFramebuffer = 0;
	}

	if(_colorRenderbuffer)
	{
		glDeleteRenderbuffersOES(1, &_colorRenderbuffer);
		_colorRenderbuffer = 0;
	}
	
	// Tear down context
	if([EAGLContext currentContext] == _context) { [EAGLContext setCurrentContext:nil]; }
	
	[_context release];
	_context = nil;
	
	[super dealloc];
}

@end
