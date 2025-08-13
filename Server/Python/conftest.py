import sys
import os

print("="*20 + " Pytest sys.path " + "="*20)
for p in sys.path:
    print(p)
print("="*50)

print("="*20 + " Pytest CWD " + "="*20)
print(os.getcwd())
print("="*50)
