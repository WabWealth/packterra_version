packer {
    required_version = ">=1.9.0"

    required_plugins {
        amazon = {
            source = "github.com/hashicorp/amazon"
            version = ">= 1.2.0"
        }
    }
}


#----------------------------------------------------------
# source: how we build the AMI For Nginx, GIT
#----------------------------------------------------------

source "amazon-ebs" "nginx-git" {
    region = "eu-west-1"
    instance_type = "t3.micro"
    ssh_username = "ec2-user"
    source_ami  = "ami-08b6a2983df6e9e25" 
    ami_name = "nginx-git-by-packer"
    ami_virtualization_type  = "hvm"
}


#----------------------------------------------------------
# source: how we build the AMI For Python
#----------------------------------------------------------

source "amazon-ebs" "python-git" {
    region = "eu-west-1"
    instance_type = "t3.micro"
    ssh_username = "ec2-user"
    source_ami  = "ami-08b6a2983df6e9e25" 
    ami_name = "python-git-by-packer"
    ami_virtualization_type  = "hvm"
}


#----------------------------------------------------------
# source: how we build the AMI For Java
#----------------------------------------------------------

source "amazon-ebs" "java-git" {
    region = "eu-west-1"
    instance_type = "t3.micro"
    ssh_username = "ec2-user"
    source_ami  = "ami-08b6a2983df6e9e25" 
    ami_name = "java-git-by-packer"
    ami_virtualization_type  = "hvm"
}



#------------------------------------
# build: source + provisioning to do 
#------------------------------------

build  {
    name  = "nginx-git-ami-build"
    sources = [
        "source.amazon-ebs.nginx-git" 
    ]

    provisioner "shell" {
        inline = [
            "sudo yum update -y",
            "sudo yum install nginx -y",
            "sudo systemctl enable nginx",
            "sudo systemctl start nginx",
            "sudo yum install git -y"
        ]
    }

    post-processor "shell-local" {
        inline = ["echo 'AMI build is finished For Nginx' "]
    }


}


build  {
    name  = "python-git-ami-build"
    sources = [
        "source.amazon-ebs.python-git" 
    ]

    provisioner "shell" {
        inline = [
            "sudo yum update -y",
            "sudo yum install python3 -y",
            "sudo yum install git -y"
        ]
    }

    post-processor "shell-local" {
        inline = ["echo 'AMI build is finished For Python' "]
    }


}


build  {
    name  = "java-git-ami-build"
    sources = [
        "source.amazon-ebs.java-git"
    ]

    provisioner "shell" {
        inline = [
            "sudo yum update -y",
            "sudo yum install java-17-amazon-corretto -y",
            "sudo yum install git -y"
        ]
    }

    post-processor "shell-local" {
        inline = ["echo 'AMI build is finished For Java' "]
    }

}








