terraform {
  required_version = "= 0.12.3"

  # Comment out when bootstrapping
  backend "s3" {
    bucket = "security-vulnerability-state-bucket-01"
    key    = "vuln-tooling.tfstate"
    region = "eu-west-2"
  }
}

provider "aws" {
  region = "eu-west-2"
}

locals {
# Set your SSH public keys here for who you want to be able to access the instance
# Remove the existing keys
  ssh-pub-key-1 = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQChXVB0+ZEc2KB1147WHGbhSUGyB2xeLnwJ4CW9V9hWdTgGWMuiWOcgFc1BGGbQ2I6Be939/JzqmsNOlguB0Qq5OJgcHelgB2+qAqEb1I9gYwKFFoIOIpiG5WNNKfbY+C2OjW6zCy9n0bNdXuSDzG2becfeCtSurdoVQNwt54AEXNtQAjUqPk+T4pHpMdWpDIMamDw8PY8PG3hypr6ao5vy/vBOaIKezAGIsDnr8eVIVkaV/TCE9RRQLxpN/tXCowzRbAmIko7so5iKoQOXSzHLMk/dehDk4oQg8pdRG7n/QW3NXFg1KbS3STgUb/8uigwAVRWCEd9LysDaceUISZ2JOP2f692f/z2rA1gCQiM5qJBOTGzL980PfcnTcKA8LI7A//S+UdWEONThQlpnZf+aFTaLHLvuBNO4awOoMorDkI7FMUvyGTHKJVHqebHwBoFMKghn9tzQ/GKK+o0zNgZ5nZaVGRRzRhxv/UueYVPPlRAf0w5GRPzx4vyOc7PE4M6amIDrIG8xojVFn8m3KwQumU78m297HzWtK3CSJSDrU1k2gpHdM/8AArRtYhIyPl7w/CaC+GrVMpG3I4r1HFzR92qQ66aUanoqr40CXwL+kbyZirt3u4km2c140/qX3UJQYcmObk43MjepFxuVmRIqCqjsfBFp4ZpIqOhQdsr37Q=="
  ssh-pub-key-2 = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDNNsdJTe3Z6n+Qa2i8bVAnT7Db/23tOCKnBmeSBtqkU1EyVL2ByV22qm6SqvOqPCokuXFeY+0llkDWps9K/ZOEAlhGIZ6iRZQVeuc4O37g1Jd5Pe+ITAorqhSXpEzefr2rbR4zfKqI2eQs1LxT+RRrx+e4JqTucGBqIxJofuz2Wka06dXzFtUYv/3wPs5KAdGnLGawnQRhE0LibeSP5ut2NJ0xTkbWBoBgyWMKrzR0+iyqFNR9RghcJLvcmFK/J6KpGrc+FcJQKbQGBkMyR6+Tfs9rwnoOW4JyIpM5XkkhXFrBxVckM1vR6Wt0cNJPlNBBngw9TytnIgijbyjixru3rJd2RU1yjvC5a1SMwhyfYaZAJlNCuJmNDTwKTXeoi5hi7nqmNP7EoywWz+y1Z6BHu02waclYvkMMozU7/Nn6j6EIltbghsNiFL4I2amQDcfRMjjhYqV7wzhPsGV4OSlOwvziEO9kbyl2nPJtYAMKQd5Ox8e8Y6Xu7qFnOJGLKLMr2FZm+xCh8IO5428YbziIqo8JUSQknFaTW+wQYPxbNys7oyeOd5OH8pkvzwyyQYEu83AiMcwzbqLwBdNxoQ0Q17pQw+jnFuPq4EgMrGupI8hwYRVzR9AkQtOABZ0hi9sSDT4VAxQvbcymnCed3MGMi4urnASOXWcHQXgfaxPK2w=="
# The office-ips below are set to the GDS office egress ips, this local var is used to whitelist inbound ssh connections
  office-ips = [
    "85.133.67.244/32",
    "213.86.153.212/32",
    "213.86.153.213/32",
    "213.86.153.214/32",
    "213.86.153.235/32",
    "213.86.153.236/32",
    "213.86.153.237/32",
  ]
}

resource "aws_vpc" "vuln-tooling" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name      = "Vulnerability Tooling VPC"
    ManagedBy = "terraform"
  }
}

resource "aws_internet_gateway" "vuln-tooling-igw" {
  vpc_id = "${aws_vpc.vuln-tooling.id}"

  tags = {
    Name      = "Vulnerability Tooling Internet Gateway"
    ManagedBy = "terraform"
  }
}

resource "aws_subnet" "vuln-tooling-subnet" {
  vpc_id     = "${aws_vpc.vuln-tooling.id}"
  cidr_block = "10.0.1.0/24"
  availability_zone       = "eu-west-2a"
  map_public_ip_on_launch = true

  tags = {
    Name      = "Vulnerability Tooling Subnet in London AZ a"
    ManagedBy = "terraform"
  }
}

resource "aws_route_table" "vuln-tooling-route-table" {
  vpc_id = "${aws_vpc.vuln-tooling.id}"

  route {
    cidr_block        = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.vuln-tooling-igw.id}"
  }

  tags = {
    Name      = "Vulnerability Tooling Routing Table"
    ManagedBy = "terraform"
  }
}

resource "aws_route_table_association" "vuln-tooling-association" {
  subnet_id      = "${aws_subnet.vuln-tooling-subnet.id}"
  route_table_id = "${aws_route_table.vuln-tooling-route-table.id}"
}

data "aws_ami" "vuln-tooling-kali-ami" {
  most_recent = true
  owners      = ["679593333241"]

  filter {
    name   = "name"
    values = ["Kali*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "template_file" "kali_userdata" {
  template = "${file("cloudinit/kali-instance.yaml")}"

  vars = {
    hostname        = "kali-pentest-01"
    ssh-pub-key-1   = "${local.ssh-pub-key-1}"
    ssh-pub-key-2   = "${local.ssh-pub-key-2}"
    bootstrap-tools = "${file("cloudinit/bootstrap-tools.sh.tpl")}"
  }
}

resource "aws_security_group" "kali-pentest-sg" {
  name        = "kali-pentest-sg"
  description = "Kali PenTest Instance Security Group"
  vpc_id      = "${aws_vpc.vuln-tooling.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = local.office-ips
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "Vulnerability Tooling Security Group Kali Instance"
    ManagedBy = "terraform"
  }
}

resource "aws_instance" "kali-pentest" {
  ami           = "${data.aws_ami.vuln-tooling-kali-ami.id}"
  instance_type = "t2.medium"
  user_data     = "${data.template_file.kali_userdata.rendered}"
  monitoring    = "true"
  subnet_id     = "${aws_subnet.vuln-tooling-subnet.id}"

  vpc_security_group_ids = [
    "${aws_security_group.kali-pentest-sg.id}",
  ]
  
  tags = {
    Name      = "Vulnerability Tooling Kali Pentest Instance"
    ManagedBy = "terraform"
  }
}
