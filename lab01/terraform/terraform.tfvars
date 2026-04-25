aws_region            = "ap-southeast-1"
project_name          = "nt548-lab01"
my_ip                 = "0.0.0.0/0"

vpc_cidr              = "10.0.0.0/16"
public_subnet_cidr    = "10.0.1.0/24"
public_subnet_cidr_2  = "10.0.2.0/24"
private_subnet_cidr   = "10.0.3.0/24"
private_subnet_cidr_2 = "10.0.4.0/24"

instance_type         = "t2.micro"
key_name              = "vantai-keypair"

app_port              = 3000
db_name               = "taskdb"
db_username           = "taskuser"
db_password           = "StrongPass123!"

container_image       = "nginx:alpine"
ecs_desired_count     = 1
jwt_secret            = "your-super-secret-key-here"