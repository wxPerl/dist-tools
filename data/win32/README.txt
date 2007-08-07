* Unzip this ZIP file somewhere (let's say in c:\temp)

* Become Administrator, if necessary

* From the command prompt
  cd c:\temp
<%
  if( $] < 5.008 ) {
    # for Perl 5.6.x
    $OUT .= <<EOT;
  ppm install --location=. $package
EOT
  } else {
    # for Perl 5.8.x
    $OUT .= <<EOT;
  ppm install $package.ppd
EOT
  }
%>
Have fun!
Mattia
