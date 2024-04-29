# Blok terraform służy do konfiguracji zachowań Terraforma samego w sobie np.
# required_version jako ograniczenie wersji Terraform CLI

# Terraform korzysta z "pluginow" - "providers" - w celu interakcji z dostawcami usług np. chmurowych.
# Musimy zadeklarować wymaganych providerów, aby móc pracować z daną infrastrukturą
# - aby terraform mógł ich zainstalować i korzystać z ich funkcjonalności. Dodatkowo, niektórzy
# providers wymagają konfiguracji (np.region).

# Provider requirements - deklarujemy wymaganych providers, aby terraform mógł ich zainstalować i używać.
# Deklaracja wymagań providera składa się z lokalnej nazwy, adresu źródłowego (skąd terraform może danego pobrać)
# oraz ograniczeń wersji (zgodnie z zaleceniami hashicorp.com - powinniśmy ograniczyć z góry i z dołu a więc np. ~> 5.0)

# Jeśli version pominięte - akceptuje dowolną wersję. Zasady:
#   = (lub nic) - dokładnie ta wersja, nie można łączyć z innymi
#   != - wyklucza dokładnie tą wersję
#   >, >=, <, <= - porównanie wersji, "nowsze od", oraz "starsze od"
#   ~> - ograniczenie pesymistyczne, pozwala zwiększać tylko ostatnią cyfrę wersji np:
#       ~> 1.0.24 pozwala 1.0.5 lub 1.0.10 ale nie 1.1.0
#       ~> 1.1 pozwala 1.2 lub 1.10 ale nie 2.0
#   można wymieniać po przeciunku np. ">=1.2.0, <2.0.0"

# Nie konfigurujemy tutaj ustawień-konfiguracji providera, jak np. AWS region.

terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 5.0"
        }
    }
    required_version = ">= 1.2.0"
}

# Konfiguracja ustawień providera AWS
# Region - region AWS w którym provider będzie działać - fizycznie korzystamy z data centers w tym regionie
# Profile - nazwa profilu AWS - taka jak w pliku konfiguracyjnym config lub credentials.
# Dane uwierzytelniające oraz inne ustawienia możemy zapisać w plikach podzielonych na profile.
# Domyślnym profilem jest "default" - możemy dodawać i używać także inne.
# W pliku config - [default] lub [profile user1]
# W pliku credentials - [dafault] lub [user1] - bez słowa "profile"
# Każdy z profili może specyfikować inne dane uwierzytelniające, region, itp.
# Poprzez nazwę profilu mozemy odnieść się do odpowieniej konfiguracji.
# Pliki profili sa "współdzielone" - ustawienia danego profilu mogą być wykorzystywane przez wiele aplikacji/procesów
# w środowisku lokalnym użytkownika
provider "aws" {
    region = "us-east-1"
    profile = "default"
}

# Virtual Private Cloud - logicznie izolowana wirtualna sieć ("fragment chmury AWS"), w której można wdrażać zasoby
# jak instancje, podsieci, grupy zabezpieczeń.

# CIDR - sposób zapisu adresów IP, który zastąpił podział oparty o klasy. CIDR "marnuje" mniej adresów.
# Notacja: adresu IP / liczba bitów adresu (maska sieciowa)
# Cidr cidr_block jest swego rodzaju zakresem - określa adres sieciowa oraz lczbę bitów z części "sieci"
# Pozostałe bity mogą być wykorzystane na adresy hostów.

# 1. Create VPC
resource "aws_vpc" "prod-vpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "VPC"
    }
}

# Podsieć w ramach danej VPC - dzieli adresy IP zdefiniowane w VPC na mniejsze bloki CIDR.
# Pozwala to na segmentację oraz kontrolę nad ruchem w sieci. W konkretnej podsieci możemy tworzyć zasoby AWS
# jak instancje EC2. Podsieć musi w całośći znajdować się w jednej Availability Zone w ramach regionu.
# Podsieci publiczne są związane z tablicą routingu z trasą do internet gateway. Jeśli w tablicy routingu
# nie ma route do internet gateway, podsieć jest prywatna.

resource "aws_subnet" "subnet-tic-tac-toe"{
    vpc_id = aws_vpc.prod-vpc.id
    cidr_block = "10.0.1.0/24"
    tags = {
        Name = "Subnet tic-tac-toe"
    }
}

# Internet Gateway - pozwala na połączenie między VPC a internetem. Zasoby z publicznych podsieci posiadające
# publiczny adres IP mogą łączyć się z internetem. Publiczny adres IP może być automatycznie przydzielany przez VPC
# lub przypisany do zasobu poprzez Elastic IP. Instancja "wie" tylko o swoim prywatnym adresie.
# Internet Gateway dostarcza NAT dla instancji, tłumacząc adres prywatny na publiczny i odwrotnie.

# 2. Create Gateway
resource "aws_internet_gateway" "gw" {
    vpc_id = aws_vpc.prod-vpc.id
    tags = {
        Name = "Gateway"
    }
}

# Route table - tablica routingu, pozwala określać zasady trasowania dla VPC - między podsieciami, gatewayami.
# Określa gdzie skierowany zostanie ruch sieciowy z podsieci lub gateway.
# Tablica może dotyczyć wielu podsieci, podsiec ma (zawsze - main route table) dokładnie jedną tablicę routingu.
# Każda route table zawiera "local route" dla komunikacji wewnątrz VPC.
# Każda zasada - Route - określa "destination" oraz "target".
# Przykładowo destination "0.0.0.0/0" (wszystkie adresy IPv4) oraz target - internet gateway
# Można tylko jedno "default route" jak "0.0.0.0/0" w route table.
resource "aws_route_table" "prod-route-table" {
    vpc_id = aws_vpc.prod-vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.gw.id
    }

    tags = {
        Name = "Route Table"
    }
}

# Wiąże podsieć/gateway z tablicą routingu.
resource "aws_route_table_association" "asc" {
    subnet_id = aws_subnet.subnet-tic-tac-toe.id
    route_table_id = aws_route_table.prod-route-table.id
}

# Zasady przychodzącego i wychodzącego ruchu sieciowego. Wirtualny "firewall" kontrolujący dostęp do związanego z nim zasobu.
# Definiujemy zasady wchodzące (ingress) - źródło, przedział portów, protokół.
# Definiujemy zasady wychodzące (egress) - cel, przedział portów, protokół.
# Zasób może miec wiele security_group - muszą być w tym samym VPC.
# "all" lub "-1" reprezentuje dowolny protokół.
# Jeśli instancja wyśle dozwolony przez zasady egress request,
# odpowiedź na to żądanie może dotrzeć do instancji niezależnie od reguł ingress.
# Jeśli instancja otrzyma dozwolone zasadami ingress żądanie, może odpowiedzieć na to żądanie niezależnie od reguł egress.
resource "aws_security_group" "sg_tic_tac_toe" {
    vpc_id = aws_vpc.prod-vpc.id
    ingress {
        description = "Client"
        from_port = 3001
        to_port = 3001
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "Server"
        from_port = 3000
        to_port = 3000
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
            description = "SSH"
            from_port = 22
            to_port = 22
            protocol = "tcp"
            cidr_blocks = ["0.0.0.0/0"]
        }

    egress {
        description = "Outbound traffic rule"
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "Security Group"
    }
}

# Interfejs sieciowy - może zostać przypisany np. do instancji EC2. Wirtualny "odpowiednik" karty sieciowej.
# Możemy przypisać jej konkretną podsieć, grupy zabezpieczeń oraz prywatne adresy IP, publiczne adresy IP.
# Instancja może mieć wiele interfejsów sieciowych, nawet z różnych podsieci.
resource "aws_network_interface" "web-server-nic" {
    subnet_id       = aws_subnet.subnet-tic-tac-toe.id
    private_ips     = ["10.0.1.50"]
    security_groups = [aws_security_group.sg_tic_tac_toe.id]
}

# Elastic IP - statyczny, publiczny adres IP który można przyznać np. instancji EC2.
# Pozostaje taki sam nawet po zatrzymaniu i restarcie instancji.
# Możemy być powiązany z konkretnym interfejsem sieciowym (musimy wtedy wyszczegółowić konkretny prywatny adres ip)
# lub bezpośrednio instancją.
# Publiczny adres ma sens wyłącznie przy istnieniu internet gateway - stąd "depends_on" - z dokumentacji
resource "aws_eip" "one" {
    domain = "vpc"
    network_interface = aws_network_interface.web-server-nic.id
    associate_with_private_ip = "10.0.1.50"
    depends_on = [aws_internet_gateway.gw]
}

# Służy do kontroli dostępu do instancji EC2 - do potwierdzenia swojej tożsamości przy np. połączeniu SSH.
# Pojawia się zagrożenie - osoba posiadająca prywatny wyklucza może uzyskać dostęp do instancji.
resource "aws_key_pair" "deployer" {
    key_name   = "main-key"
    public_key = "${file("id_rsa.pub")}"
}

# AMI - amazon machine image - obraz potrzebny do stworzenia instancji
# Instance type - hardware komputera wykorzystanego dla instancji.
# t2.micro - 1 GiB RAM, 1 vCPU
# Network interface - przypisanie interfejsu sieciowego do instancji przy określonym device_index
# Maksymalny device_index zależy od rodzaju instancji
# User_data - dane użytkowika dostarczane przy tworzeniu instacji - np.skrypt do uruchomienia.
resource "aws_instance" "ec2-instance" {
    ami = "ami-04e5276ebb8451442"
    instance_type = "t2.micro"
    key_name = "main-key"
    depends_on = [aws_eip.one]

    network_interface {
        network_interface_id = aws_network_interface.web-server-nic.id
        device_index = 0
    }

    user_data = "${file("install.sh")}"
    tags = {
        Name = "EC2 Instance"
    }
}