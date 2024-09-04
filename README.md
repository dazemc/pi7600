Python library for accessing [7600G-H from Waveshare.](https://www.waveshare.com/wiki/SIM7600G-H_4G_HAT_(B)) This should
be compatiable with all SIM7600's using either windows or linux. The only requirement is Python 3.10 or greater, recommend dnsmasq.
\
\
\
\
\
\
\
\
\
\
\
----------KNOWN BUGS-----------
<li>
  TypeError: unsupported operand type(s) for |: 'type' and 'type':
  <br><br>
  <ul>
    <em>The default Python version in Raspberry Pi OS is 3.9
    This project uses some of the type hinting syntax that was available starting with Python-3.10. Therefore, the most         recent stable version is bundled with this repository.
    If you'd rather build from source, simply run the buildpy.sh bash script.</em>
  </ul>
</li>
<!---<br><br>
<li>
  [ERROR TITLE]
  <br><br>
  <ul>
    <em>[ERROR CONTENT]</em>
  </ul>
</li>--->
<br><br>
----------Resources/Notes------------
<br><br>
<li><a href="https://www.waveshare.com/wiki/SIM7600G-H_4G_HAT_(B)">Product Page</a></li>
<br>
<li><a href="https://www.waveshare.net/w/upload/6/68/SIM7500_SIM7600_Series_AT_Command_Manual_V2.00.pdf">SIM7600 AT Command Manual</a></li>
<br>
<li><a href="https://www.waveshare.com/w/upload/7/79/SIM7X00_Series_TCPIP_Application_Note_V1.00.pdf"> SIM7X00 TCPIP Manual</a></li>
