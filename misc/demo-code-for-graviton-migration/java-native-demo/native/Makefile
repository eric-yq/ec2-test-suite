# Makefile for building libmathutils.so

# Java home detection
JAVA_HOME ?= $(shell readlink -f /usr/bin/javac | sed "s:bin/javac::")

# Compiler and flags
CXX = g++
CXXFLAGS = -fPIC -shared -O2 -Wall
INCLUDES = -I$(JAVA_HOME)/include -I$(JAVA_HOME)/include/linux

# Target and source
TARGET = libmathutils.so
SOURCE = mathutils.cpp

# Build rule
$(TARGET): $(SOURCE)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -o $(TARGET) $(SOURCE)

# Clean rule
clean:
	rm -f $(TARGET)

# Install rule (copy to parent resources directory)
install: $(TARGET)
	@mkdir -p ../src/main/resources/
	cp $(TARGET) ../src/main/resources/

.PHONY: clean install
