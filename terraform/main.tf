resource "aws_vpc" "hub" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "hub-vpc"
  }
}

resource "aws_subnet" "hub_public_a" {
  vpc_id            = aws_vpc.hub.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "hub-public-a"
  }
}

resource "aws_subnet" "hub_public_b" {
  vpc_id            = aws_vpc.hub.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "hub-public-b"
  }
}

resource "aws_subnet" "hub_tgw_a" {
  vpc_id            = aws_vpc.hub.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "hub-tgw-a"
  }
}

resource "aws_subnet" "hub_tgw_b" {
  vpc_id            = aws_vpc.hub.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "hub-tgw-b"
  }
}

resource "aws_internet_gateway" "hub_igw" {
  vpc_id = aws_vpc.hub.id

  tags = {
    Name = "hub-igw"
  }
}

resource "aws_route_table" "hub_public" {
  vpc_id = aws_vpc.hub.id

  tags = {
    Name = "hub-public-rt"
  }
}

resource "aws_route" "hub_to_internet" {
  route_table_id         = aws_route_table.hub_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.hub_igw.id
}

resource "aws_route_table_association" "hub_public_a" {
  subnet_id      = aws_subnet.hub_public_a.id
  route_table_id = aws_route_table.hub_public.id
}

resource "aws_route_table_association" "hub_public_b" {
  subnet_id      = aws_subnet.hub_public_b.id
  route_table_id = aws_route_table.hub_public.id
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "hub-nat-eip"
  }
}

resource "aws_nat_gateway" "hub_nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.hub_public_a.id

  tags = {
    Name = "hub-nat"
  }

  depends_on = [
    aws_internet_gateway.hub_igw
  ]
}

resource "aws_route_table" "hub_tgw" {
  vpc_id = aws_vpc.hub.id

  tags = {
    Name = "hub-tgw-rt"
  }
}

resource "aws_route" "hub_tgw_to_spoke" {
  route_table_id         = aws_route_table.hub_tgw.id
  destination_cidr_block = "10.1.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
}

resource "aws_route" "hub_tgw_to_nat" {
  route_table_id         = aws_route_table.hub_tgw.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.hub_nat.id
}

resource "aws_route_table_association" "hub_tgw_a" {
  subnet_id      = aws_subnet.hub_tgw_a.id
  route_table_id = aws_route_table.hub_tgw.id
}

resource "aws_route_table_association" "hub_tgw_b" {
  subnet_id      = aws_subnet.hub_tgw_b.id
  route_table_id = aws_route_table.hub_tgw.id
}

resource "aws_vpc" "spoke" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "spoke-vpc"
  }
}

resource "aws_subnet" "spoke_private_a" {
  vpc_id            = aws_vpc.spoke.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "ap-south-1a"
  tags = {
    Name = "spoke-private-a"
  }
}

resource "aws_subnet" "spoke_private_b" {
  vpc_id            = aws_vpc.spoke.id
  cidr_block        = "10.1.2.0/24"
  availability_zone = "ap-south-1b"
  tags = {
    Name = "spoke-private-b"
  }
}

resource "aws_ec2_transit_gateway" "tgw" {
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  tags = {
    Name = "hub-spoke-tgw"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "hub" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = aws_vpc.hub.id
  subnet_ids = [
    aws_subnet.hub_tgw_a.id,
    aws_subnet.hub_tgw_b.id
  ]
  tags = {
    Name = "hub-tgw-attachment"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "spoke" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = aws_vpc.spoke.id
  subnet_ids = [
    aws_subnet.spoke_private_a.id,
    aws_subnet.spoke_private_b.id
  ]
  tags = {
    Name = "spoke-tgw-attachment"
  }
}

resource "aws_route_table" "spoke_private" {
  vpc_id = aws_vpc.spoke.id

  tags = {
    Name = "spoke-private-rt"
  }
}

resource "aws_route_table_association" "spoke_private_a" {
  subnet_id      = aws_subnet.spoke_private_a.id
  route_table_id = aws_route_table.spoke_private.id
}

resource "aws_route_table_association" "spoke_private_b" {
  subnet_id      = aws_subnet.spoke_private_b.id
  route_table_id = aws_route_table.spoke_private.id
}

resource "aws_route" "spoke_to_hub" {
  route_table_id         = aws_route_table.spoke_private.id
  destination_cidr_block = "10.0.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
}

resource "aws_route" "spoke_to_internet" {
  route_table_id         = aws_route_table.spoke_private.id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
}

resource "aws_route" "hub_to_spoke" {
  route_table_id         = aws_route_table.hub_public.id
  destination_cidr_block = "10.1.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id
}

resource "aws_security_group" "alb" {
  name        = "hub-alb-sg"
  description = "Security group for Hub ALB"
  vpc_id      = aws_vpc.hub.id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "hub-alb-sg"
  }
}

resource "aws_lb" "hub_alb" {
  name               = "hub-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.alb.id
  ]

  subnets = [
    aws_subnet.hub_public_a.id,
    aws_subnet.hub_public_b.id
  ]

  tags = {
    Name = "hub-alb"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.hub_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Service not found"
      status_code  = "404"
    }
  }
}

resource "aws_ecs_cluster" "spoke" {
  name = "spoke-ecs-cluster"

  tags = {
    Name = "spoke-ecs-cluster"
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "ecs_task_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecr_repository" "ui" {
  name                 = "user-ui"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "user-ui"
  }
}

resource "aws_ecr_repository" "api" {
  name                 = "user-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "user-api"
  }
}

resource "aws_ecs_task_definition" "ui" {
  family                   = "ui-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  cpu    = "256"
  memory = "512"

  execution_role_arn = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "ui"
      image     = "553336999743.dkr.ecr.ap-south-1.amazonaws.com/user-ui:latest"
      essential = true

      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]
    }
  ])

  tags = {
    Name = "ui-task"
  }
}

resource "aws_ecs_task_definition" "api" {
  family                   = "api-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  cpu    = "256"
  memory = "512"

  execution_role_arn = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = "${aws_ecr_repository.api.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 5000
          protocol      = "tcp"
        }
      ]
    }
  ])

  tags = {
    Name = "api-task"
  }
}

resource "aws_security_group" "ecs" {
  name        = "spoke-ecs-sg"
  description = "Security group for ECS Fargate tasks"
  vpc_id      = aws_vpc.spoke.id

  ingress {
    description = "Allow UI HTTP from Hub VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    description = "Allow API HTTP from Hub VPC"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "spoke-ecs-sg"
  }
}

resource "aws_lb_target_group" "api" {
  name        = "user-api-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.hub.id
  target_type = "ip"

  health_check {
    path                = "/api/health"
    protocol            = "HTTP"
    port                = 5000
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
  }

  tags = {
    Name = "user-api-tg"
  }
}

resource "aws_lb_target_group" "ui" {
  name     = "user-ui-tg"
  port     = 80
  protocol = "HTTP"

  vpc_id = aws_vpc.hub.id

  target_type = "ip"

  health_check {
    path     = "/"
    protocol = "HTTP"
    port     = "traffic-port"

    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
  }

  tags = {
    Name = "user-ui-tg"
  }
}

resource "aws_lb_listener_rule" "ui" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ui.arn
  }

  condition {
    path_pattern {
      values = ["/ui", "/ui/*"]
    }
  }

   transform {
    type = "url-rewrite"

    url_rewrite_config {
      rewrite {
        regex   = "^/ui/?(.*)$"
        replace = "/$1"
      }
    }
  }
}

resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  condition {
    path_pattern {
      values = ["/api", "/api/*"]
    }
  }
}

resource "aws_ecs_service" "api" {
  name            = "user-api-service"
  cluster         = aws_ecs_cluster.spoke.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets = [
      aws_subnet.spoke_private_a.id,
      aws_subnet.spoke_private_b.id
    ]

    security_groups = [
      aws_security_group.ecs.id
    ]

    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = 5000
  }

  depends_on = [
    aws_lb_listener.http,
    aws_lb_listener_rule.api,
    aws_route_table_association.hub_tgw_a,
    aws_route_table_association.hub_tgw_b
  ]
}

resource "aws_ecs_service" "ui" {
  name            = "user-ui-service"
  cluster         = aws_ecs_cluster.spoke.id
  task_definition = aws_ecs_task_definition.ui.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets = [
      aws_subnet.spoke_private_a.id,
      aws_subnet.spoke_private_b.id
    ]

    security_groups = [
      aws_security_group.ecs.id
    ]

    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ui.arn
    container_name   = "ui"
    container_port   = 80
  }

  depends_on = [
    aws_lb_listener.http,
    aws_lb_listener_rule.ui,
    aws_route_table_association.hub_tgw_a,
    aws_route_table_association.hub_tgw_b
  ]
}