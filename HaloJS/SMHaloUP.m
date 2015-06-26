//
//  SMHaloHUD.m
//  HaloHUD
//
//  Created by Samuco on 11/23/13.
//  Copyright (c) 2013. All rights reserved.
//

#import "SMHaloUP.h"
#import "mach_override.h"
#include <wchar.h>

#import <OpenGL/glext.h>
#import <OpenGL/glu.h>
#import <Carbon/Carbon.h>
#import <AGL/AGL.h>

@implementation SMHaloUP

void nop(uint32_t offset, size_t size) {
    int i;
    for (i=0; i < size; i++) {
        *(int8_t  *)(offset + i) = 0x90;
    }
}

#pragma mark INTEGRATED GRAPHICS FIX
-(void)integratedGraphics {
    // changes
    // jz short 0x2b3ecd	74 2B
    // to
    // jmp short 0x2b3ecd	EB 2B
    *(uint8_t*)0x2B3EA0 = 0xEB;
}

#pragma mark PIXEL ATTRIBUTES
// This is broken.
-(void)pixelAttributes {
    nop(0x2B39E6, 45);
    uint32_t attrib[] = {
        AGL_RGBA,
        AGL_DEPTH_SIZE, 0x10,
        //0x48, 0x49,
        AGL_DOUBLEBUFFER,
        AGL_MAXIMUM_POLICY,
        AGL_OFFSCREEN,
        AGL_SAMPLE_BUFFERS_ARB, 10,
        AGL_SAMPLES_ARB, 4,
        AGL_SUPERSAMPLE,
        AGL_SAMPLE_ALPHA,
        0
    };
    int size = sizeof(uint32_t) * 20;
    void *attribs = malloc(size);
    memcpy(attribs, attrib, 15);
    *(uint8_t *)0x2B39E6  = 0xb8;
    *(uint8_t**)0x2B39E7 = (uint8_t*)attribs;
}

#pragma mark CPU USAGE
uint32_t (*old_sub_243f48)() = NULL;
uint32_t sub_243f48() {
    ProcessSerialNumber serial; GetFrontProcess(&serial);
    ProcessSerialNumber psn; GetCurrentProcess(&psn);
    if (psn.lowLongOfPSN != serial.lowLongOfPSN) {
        usleep(10000);
    }
    
    return old_sub_243f48();
}
-(void)cpufix {
    mach_override_ptr((void *)0x243f48, sub_243f48, (void **)&old_sub_243f48);
}

#pragma mark EXTRA RESOLUTION
void writeUTF16String(mach_vm_address_t pointerToObject, NSString *message)
{
    NSUInteger numberOfBytes = [message lengthOfBytesUsingEncoding:NSUnicodeStringEncoding];
    void *buffer = malloc(numberOfBytes);
    NSUInteger usedLength = 0;
    NSRange range = NSMakeRange(0, [message length]);
    BOOL result = [message getBytes:buffer maxLength:numberOfBytes usedLength:&usedLength encoding:NSUnicodeStringEncoding options:0 range:range remainingRange:NULL];
    
    if (result) {
        memcpy((void*)pointerToObject, buffer, numberOfBytes);
    }
    
    free(buffer);
}

uint32_t (*old_sub_1eea70)() = NULL;
uint32_t sub_1eea70() {
    
    // Add resolutions above 21
    uint8_t number = *((uint8_t*)0x3D65E0);
    NSScreen *main = [NSScreen mainScreen];
    NSSize max = [[[main deviceDescription] valueForKey:NSDeviceSize] sizeValue];
    
    // Does this resolution exist in the table?
    int i;
    for (i=0; i < number; i++) {
        uint8_t *resolution_pointer = (uint8_t *)(0x3D5C60 + 0x4C * i);
        uint32_t width  = *(uint32_t*)resolution_pointer;
        uint32_t height = *(uint32_t*)(resolution_pointer + 4);
        
        if (width == max.width && height == max.height) {
            // The resolution exists.
            return old_sub_1eea70();
        }
    }
    
    // Add the new resolution
    uint8_t *resolution_pointer = (uint8_t *)(0x3D5C60 + 0x4C * number);
    
    // Reallocate the resolution table
    *(uint32_t*)(resolution_pointer)     = (uint32_t)max.width;
    *(uint32_t*)(resolution_pointer + 4) = (uint32_t)max.height;
    mach_vm_address_t display_text = (mach_vm_address_t)(resolution_pointer + 8);
    memset((void*)display_text, 0, 0x20);
    @autoreleasepool {
        writeUTF16String(display_text, [NSString stringWithFormat:@"%d x %d", (uint32_t)max.width, (uint32_t)max.height]);
    }

    // Random table entries - maybe Hz?
    *(uint32_t*)(resolution_pointer + 0x28) = 1;
    *(uint32_t*)(resolution_pointer + 0x2C) = 0x3C;
    
    // Override the code to compare
    mprotect((void *)0xE0000,0x1FFFFE, PROT_READ|PROT_WRITE);
    
    // Add
    nop(0x175120, 6);
    *(uint8_t*)0x175120 = 0x83;
    *(uint8_t*)0x175121 = 0xFA;
    *(uint8_t*)0x175122 = number+1;
    
    // Sub
    nop(0x1750C2, 7);
    *(uint8_t *)0x1750C2 = 0xB8;
    *(uint32_t*)0x1750C3 = number;
    
    mprotect((void *)0xE0000,0x1FFFFE, PROT_READ|PROT_EXEC);
    
    // Write the new counts
    *((uint8_t*)0x3D65E0) = number + 1;
    return old_sub_1eea70();
}

-(void)extra_resolutions {
    mach_override_ptr((void *)0x1eea70, sub_1eea70, (void **)&old_sub_1eea70);
}

#pragma mark ELCAP WINDOW FIX
-(void)elcap_fix {
    CGDirectDisplayID mainID = CGMainDisplayID(); GDHandle mainDevice;
    DMGetGDeviceByDisplayID(mainID, &mainDevice, true);
    (*(uint32_t*)(*(uint32_t*)*(uint32_t*)((*(uint32_t*)mainDevice) + 0x16) + 0x20)) = 0x20;
}

#pragma mark ANSIOTROPICAL FILTERING
bool aa_enabled;
float fLargest;

void aa_toggle() {
    aa_enabled ? aa_disable() : aa_enable();
}

void aa_enable() {
    glGetFloatv(GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT, &fLargest);
    aa_enabled = true;
}

void aa_disable() {
    aa_enabled = false;
}

uint32_t (*old_sub_2e4554)() = NULL;
uint32_t sub_2e4554(uint32_t arg_x0) {
    if (aa_enabled) {
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAX_ANISOTROPY_EXT, fLargest);
    } else {
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAX_ANISOTROPY_EXT, 1.0);
    }
    
    uint32_t val = old_sub_2e4554();
    return val;
}

-(void)ansi {
    mach_override_ptr((void *)0x2e4554, sub_2e4554, (void **)&old_sub_2e4554);
}

#pragma mark BSP BOOST

// Reallocate the BSP table to enable bigger BSPs
-(void)bsp {
    uint32_t *objectCacheArrayPointer = (uint32_t*)0x5B5100;
    void* buffer_location = (void*)(*objectCacheArrayPointer);
    int old_array_length = pow(2,16);
    int new_array_length = pow(2,20);
    void *new_array = malloc(new_array_length);
    int array_position = (int)new_array;
    memcpy(new_array, buffer_location, old_array_length);
    memcpy(objectCacheArrayPointer, &array_position, 4);
    
    uint16_t bspLimit = 0xFFF0;
    *(int32_t *)(0x2305FE + 0) = (int32_t)new_array;
    *(int32_t *)(0x230607 + 0) = (int32_t)new_array+0xC;
    *(int32_t *)(0x23060F + 0) = (int32_t)new_array+0x10;
    *(int32_t *)(0x22FAB5 + 3) = (int32_t)new_array+0x14;
    *(int32_t *)(0x23068A + 0) = (int32_t)new_array+0xA;
    *(int32_t *)(0x2306BF + 3) = (int32_t)new_array+0x14;
    *(int32_t *)(0x2306D3 + 4) = (int32_t)new_array+0x68;
    *(int32_t *)(0x2306E3 + 3) = (int32_t)new_array+0x14;
    *(int32_t *)(0x22FA7A + 2) = (int32_t)new_array+0x4;
    *(int32_t *)(0x2307FB + 4) = (int32_t)new_array+0x68;
    *(int32_t *)(0x23080B + 3) = (int32_t)new_array+0x14;
    *(int32_t *)(0x2305FC + 2) = (int32_t)new_array;
    *(int32_t *)(0x22FA9F + 3) = (int32_t)new_array+0x8;
    *(int32_t *)(0x22FAD0 + 3) = (int32_t)new_array+0x68;
    *(int32_t *)(0x22FB46 + 4) = (int32_t)new_array+0x1F4;
    *(int32_t *)(0x22FC0F + 3) = (int32_t)new_array+0x290;
    *(int32_t *)(0x22FB2A + 3) = (int32_t)new_array+0xA;
    *(int32_t *)(0x22FC9E + 3) = (int32_t)new_array+0x290;
    *(int32_t *)(0x22FCDA + 3) = (int32_t)new_array+0x290;
    *(int32_t *)(0x22FDDE + 4) = (int32_t)new_array+(0x4f4688 - 0x4f4620);
    *(int32_t *)(0x22FDE6 + 3) = (int32_t)new_array+(0x4f4634 - 0x4f4620);
    *(int32_t *)(0x22FE32 + 4) = (int32_t)new_array+(0x4f4814 - 0x4f4620);
    *(int32_t *)(0x22FE54 + 4) = (int32_t)new_array+(0x4f4814 - 0x4f4620);
    *(int32_t *)(0x22FE5C + 3) = (int32_t)new_array+(0x4f4868 - 0x4f4620);
    *(int32_t *)(0x22FE6B + 4) = (int32_t)new_array+(0x4f482c - 0x4f4620);
    *(int32_t *)(0x22FE88 + 4) = (int32_t)new_array+(0x4f4854 - 0x4f4620);
    *(int32_t *)(0x22FD6D + 3) = (int32_t)new_array+(0x4f48b0 - 0x4f4620);
    *(int32_t *)(0x22FDE6 + 3) = (int32_t)new_array+(0x4f4634 - 0x4f4620);
    *(int32_t *)(0x22FE3E + 3) = (int32_t)new_array+(0x4f486e - 0x4f4620);
    *(int32_t *)(0x22FEB4 + 3) = (int32_t)new_array+(0x4f4824 - 0x4f4620);
    *(int16_t *)(0x25FA04) = bspLimit;
    *(int16_t *)(0x25FA45) = bspLimit;
    *(int16_t *)(0x25FA75) = bspLimit;
    *(int8_t  *)(0x25FA06) = 0x7C;
    *(int16_t *)(0x25FA47) = 0x8D0F;
    *(int16_t *)(0x25FA77) = 0x8D0F;
}

#pragma mark VISIBLE OBJECT LIMIT

// Increase the visible object limit
typedef struct
{
    uint16_t objectTableIndex;
    uint16_t objectTableIndexPlusSomething;
} ObjectID;

-(void)object_limit {
    struct ObjectId *objects = (void *)0x405d64; //old objects array location - will change after calloc
    int16_t newLimit = 0x2000;
    objects = calloc(sizeof(ObjectID),newLimit);
    *(struct ObjectId **)(0x235CAE + 3) = objects;
    *(struct ObjectId **)(0x235B82 + 3) = objects;
    *(struct ObjectId **)(0x235C47 + 3) = objects;
    *(struct ObjectId **)(0x235BFF + 3) = objects;
    *(int32_t *)(0x235BF7 + 4) = newLimit;
    *(int32_t *)(0x235C37 + 1) = newLimit;
}

#pragma mark SETUP
- (id)initWithMode:(MDPluginMode)mode
{
	self = [super init];
	if (self != nil)
	{
        map_mode = mode;
        
        mprotect((void *)0xE0000,0x1FFFFE, PROT_READ|PROT_WRITE);
        [self elcap_fix];
        [self bsp];
        [self object_limit];
        [self ansi];
        //[self extra_resolutions];
        [self cpufix];
        //[self pixelAttributes]; <-- broken
        [self integratedGraphics];
        mprotect((void *)0xE0000,0x1FFFFE, PROT_READ|PROT_EXEC);
	}
	return self;
}

// Shameless self promotion
typedef enum
{
    NONE = 0x0,
    WHITE = 0x343aa0,
    GREY = 0x343ab0,
    BLACK = 0x343ac0,
    RED = 0x343ad0,
    GREEN = 0x343ae0,
    BLUE = 0x343af0,
    CYAN = 0x343b00,
    YELLOW = 0x343b10,
    MAGENTA = 0x343b20,
    PINK = 0x343b30,
    COBALT = 0x343b40,
    ORANGE = 0x343b50,
    PURPLE = 0x343b60,
    TURQUOISE = 0x343b70,
    DARK_GREEN = 0x343b80,
    SALMON = 0x343b90,
    DARK_PINK = 0x343ba0
} ConsoleColor;

void (*consolePrintf)(int color, const char *format, ...) = (void *)0x1588a8;
-(void)activatePlugin
{
    shownMessage = YES;
    pluginIsActive = YES;
    
    // Start ansiotropical
    aa_enable();
}

- (void)mapDidBegin:(NSString *)mapName
{
    [self performSelector:@selector(activatePlugin) withObject:nil afterDelay:1];
}

- (void)mapDidEnd:(NSString *)mapName
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(activatePlugin) object:nil];
}

@end
