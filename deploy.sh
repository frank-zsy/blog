# commit to git server
git add .
git commit -m 
msg="update blog $(date)"
if [ -n "$*" ]; then
	msg="$*"
fi
git commit -m "$msg"

# deploy to serverless
s deploy
