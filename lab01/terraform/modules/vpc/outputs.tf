output "vpc_id"              { value = aws_vpc.main.id }
output "public_subnet_id"    { value = aws_subnet.public_1.id }
output "public_subnet_id_2"  { value = aws_subnet.public_2.id }
output "private_subnet_id"   { value = aws_subnet.private_1.id }
output "private_subnet_id_2" { value = aws_subnet.private_2.id }
output "nat_gateway_ip"      { value = aws_eip.nat.public_ip }
output "public_subnet_ids"   { value = [aws_subnet.public_1.id, aws_subnet.public_2.id] }
output "private_subnet_ids"  { value = [aws_subnet.private_1.id, aws_subnet.private_2.id] }