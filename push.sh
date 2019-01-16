#! /bin/bash

git add .

read -p "输入commit的注释：" Comment

git commit -m "$Comment"

git push -u origin master
