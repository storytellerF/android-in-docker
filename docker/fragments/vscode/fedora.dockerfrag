USER root

RUN rpm --import https://packages.microsoft.com/keys/microsoft.asc \
    && printf '[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc\n' \
        > /etc/yum.repos.d/vscode.repo

RUN dnf install -y code \
    && dnf clean all
