import pika, os, sys

if (len(sys.argv) != 2):
    print("Commmand line parameter missing")
    exit(0)
url = os.environ.get('AMQP_URL', 'amqp://guest:guest@localhost:5672/%2f')
params = pika.URLParameters(url)
connection = pika.BlockingConnection(params)
channel = connection.channel()  # start a channel
channel.queue_declare(queue='github', durable=True)  # Declare a queue
channel.basic_publish(exchange='', routing_key='github', body=sys.argv[1])

print(" [x] Sent " + sys.argv[1])
connection.close()