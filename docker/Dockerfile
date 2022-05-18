FROM python:3

WORKDIR /main

ENV PYTHONPATH=/main

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD [ "python", "/main/app/server/server.py" ]
