check_ipmitools()
{

    which ipmitool > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Could not locate ipmitool on system"
        exit 1
    fi
}

check_mlxconfig()
{
    which mlxconfig > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Could not locate mlxconfig on system"
        exit 1
    fi
}

check_mstconfig()
{
    which mstconfig > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Could not locate mstconfig on system"
        exit 1
    fi

}

check_pdsh()
{
    which pdsh > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Could not locate pdsh on system"
        exit 1
    fi

}