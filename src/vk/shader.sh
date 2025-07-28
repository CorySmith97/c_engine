#!/usr/local/bin/bash

glslc -o src/shaders/basicvs.spriv src/shaders/basic.vert
glslc -o src/shaders/basicfs.spriv src/shaders/basic.frag
