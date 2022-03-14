#!/usr/bin/env nodejs

const https = require('https');
const http = require('http');
const fs = require('fs');
const url = require('url');
require('dotenv').config();

const portHttp = process.env.PORTHTTP;
const portSSL = process.env.PORTSSL;
const color = process.env.SCOLOR;

// Object which will be printed on server response
let socketDetails = {
    ladd:'',
    lport:'',
    radd:'',
    rport:''
};

// Option of the SSL server
const optionsSSL = {
  key: fs.readFileSync('./openssl/srv.key'),
  cert: fs.readFileSync('./openssl/srv.crt'),
  requestCert: true,
  rejectUnauthorized: false, // so we can do own error handling
  ca: [
    fs.readFileSync('./openssl/ca.crt')
  ]
};

// Create https server
var serverSSL = https.createServer(optionsSSL);
serverSSL.on('request',(req,res)=>{
    //Create some cpu load
    let f = (url.parse(req.url,true).query.f)?parseInt(url.parse(req.url,true).query.f):0;
    socketDetails.ladd = req.socket.localAddress;
    socketDetails.lport = req.socket.localPort;
    socketDetails.radd = req.socket.remoteAddress;
    socketDetails.rport = req.socket.remotePort;
    console.log(JSON.stringify(socketDetails, null, '\t'))
    res.write(`<body bgcolor="${color}">\n`);
    res.write(`in:${f},out:${fibo(f)}\n`);
    res.write(`${JSON.stringify(req.headers, null, '\t')}\n`);
    res.write(`${JSON.stringify(socketDetails, null, '\t')}\n`);    
    //Verify if user did send client certificate.
    if (req.socket.authorized){
        res.write(`client-cert:${req.socket.getPeerCertificate().subject.CN}\n`);
    }
    res.write(`</body>\n`);
    res.end();
});
serverSSL.listen(portSSL,'0.0.0.0',()=>{
    console.log(`ServerSSL waiting on port ${portSSL} for you`)
})

// Create http server
var server = http.createServer();
server.on('request',(req,res)=>{
    //Create some cpu load
    let f = (url.parse(req.url,true).query.f)?parseInt(url.parse(req.url,true).query.f):0;
    socketDetails.ladd = req.socket.localAddress;
    socketDetails.lport = req.socket.localPort;
    socketDetails.radd = req.socket.remoteAddress;
    socketDetails.rport = req.socket.remotePort;
    console.log(JSON.stringify(socketDetails, null, '\t'))
    res.write(`<body bgcolor="${color}">\n`);
    res.write(`in:${f},out:${fibo(f)}\n`);
    res.write(`${JSON.stringify(req.headers, null, '\t')}\n`);
    res.write(`${JSON.stringify(socketDetails, null, '\t')}\n`);   
    res.write(`</body>\n`);
    res.end();
});

server.listen(portHttp,'0.0.0.0',()=>{
    console.log(`ServerHTTP waiting on port ${portHttp} for you`)
})

function fibo(num){
    if(num<=1){
        return num;
    }else{
        return fibo(num-1)+fibo(num-2);
    }
}
