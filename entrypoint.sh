#! /bin/bash
mkdir -p /code/logs

cp /code/nginx.conf /etc/nginx/sites-enabled/default
sed -i -e 's|replaceme|'"$BACKEND_HOST:$BACKEND_HOST_PORT"'|g' /etc/nginx/sites-enabled/default
service nginx restart

if [ $IS_FRONT ]; then
    sed -i -e 's|changeme|'"$BACKEND_HOST:$BACKEND_HOST_PORT"'|g' /code/ownphotos-frontend/src/api_client/apiClient.js
    cd /code/ownphotos-frontend
    npm run build
    serve -s build
else
    source /venv/bin/activate
    python manage.py makemigrations api 2>&1 | tee logs/makemigrations.log
    python manage.py migrate 2>&1 | tee logs/migrate.log

python manage.py shell <<EOF
from api.models import User
User.objects.filter(email='$ADMIN_EMAIL').delete()
User.objects.create_superuser('$ADMIN_USERNAME', '$ADMIN_EMAIL', '$ADMIN_PASSWORD')
EOF


    echo "Running backend server..."

    python manage.py rqworker default 2>&1 | tee logs/rqworker.log &
    gunicorn --bind 0.0.0.0:"$BACKEND_HOST_PORT" ownphotos.wsgi 2>&1 | tee logs/gunicorn.log
fi