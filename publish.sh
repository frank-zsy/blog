git add .
git commit -sm "update blog"
git push -f origin master
npm run build
ossutil sync -f --delete ./public oss://frankblog
