#!/bin/bash
export PORT=9000
cd /mnt/auto/blog && npx hexo server -p $PORT -s
