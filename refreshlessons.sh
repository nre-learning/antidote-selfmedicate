kubectl patch deployment syringe -p '{"spec":{"template":{"metadata":{"annotations":{"foobar":"'$(date +%s)'"}}}}}' > /dev/null
echo "Syringe is restarting. Will pull a fresh copy of lesons repository."
