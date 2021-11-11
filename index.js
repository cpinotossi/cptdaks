require('dotenv').config();
const port = process.env.PORT;
const color = process.env.SCOLOR;

const url = require('url');
const http = require('http');
const server = http.createServer();

server.on('request',(req,res)=>{
    console.log(`la:${req.socket.localAddress},lp:${req.socket.localPort},${req.url}`);
    //Create some cpu load
    let f = (url.parse(req.url,true).query.f)?parseInt(url.parse(req.url,true).query.f):0;
    res.write(`Server ${color},in:${f},out:${fubi(f)}`);
    res.end();
});

server.listen(port,()=>{
    console.log(`Server ${color} is waiting on port ${port}`);
});

function fubi(num){
    if(num<=1){
        return num;
    }else{
        return fubi(num-1)+fubi(num-2);
    }
}