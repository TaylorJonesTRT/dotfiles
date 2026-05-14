#include "sketchybar.h"
#include <CoreFoundation/CoreFoundation.h>
#include <time.h>
#include <string.h>

const int FRAME_SIZE = 16; //must be +1 longer than string legth b/c null terminator \0
const float INTERVAL = 0.25 //s

const char frames[7][FRAME_SIZE] = {
	"^~-=#&8|",
	"~==&#89|",
	"__=&##89|",
	"=_&#==89|",
	"^&*=--89|",
	"**^=-#99|",
	"*^--==9&|",
};

int i = -1;

void callback() {
  size_t length = sizeof(frames) / sizeof(frames[0]);
  i += 1;
  if (i >= length) {
    i = 0;
  }
  size_t message_size = FRAME_SIZE + 64; // frame + extra space for message
  char message[message_size];
  snprintf(message, message_size, "--set flag icon.string=\"%s\"", frames[i]);
  sketchybar(message);
}

int main() {
  CFRunLoopTimerRef timer = CFRunLoopTimerCreate(kCFAllocatorDefault, (int64_t)CFAbsoluteTimeGetCurrent() + 1.0, INTERVAL, 0, 0, callback, NULL);
  CFRunLoopAddTimer(CFRunLoopGetMain(), timer, kCFRunLoopDefaultMode);
  CFRunLoopRun();
  return 0;
}
