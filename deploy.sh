# commit to git server
git add .
git commit -m 
msg="update blog $(date)"
if [ -n "$*" ]; then
	msg="$*"
fi
git commit -m "$msg"
git push origin master

# deploy to serverless
s deploy
