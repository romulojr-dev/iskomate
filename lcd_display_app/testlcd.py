import os
import pygame
import time

# Set environment to target LCD framebuffer
os.environ["SDL_FBDEV"] = "/dev/fb1"   # LCD framebuffer
os.environ["SDL_VIDEODRIVER"] = "fbcon"  # framebuffer console driver

# Initialize pygame
pygame.init()
screen = pygame.display.set_mode((0, 0), pygame.FULLSCREEN)

# Load images
engaged_image = pygame.image.load("/home/pi/lcd_display_app/engaged.jpg")
disengaged_image = pygame.image.load("/home/pi/lcd_display_app/disengaged.jpg")

# Scale images to LCD size
screen_size = screen.get_size()
engaged_image = pygame.transform.scale(engaged_image, screen_size)
disengaged_image = pygame.transform.scale(disengaged_image, screen_size)

# Functions to show images
def show_engaged():
    screen.blit(engaged_image, (0, 0))
    pygame.display.update()

def show_disengaged():
    screen.blit(disengaged_image, (0, 0))
    pygame.display.update()

# Simple loop to alternate images for testing
while True:
    show_engaged()
    time.sleep(2)  # show for 2 seconds
    show_disengaged()
    time.sleep(2)