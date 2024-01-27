use hyper::{
    Method, Request, Response, StatusCode,
    body::Bytes,
    body::Incoming,
    service::Service,
};
use http_body_util::{
    Empty,
    Full,
    combinators::BoxBody,
    BodyExt,
};
use json::JsonValue;
use std::future::Future;
use std::net::SocketAddr;
use std::pin::Pin;
use tokio::{
    sync,
    net::TcpListener,
};
use hyper_util::{
    rt::TokioExecutor,
    rt::TokioIo,
    server::conn::auto,
};
use base64::prelude::*;

use crate::msg::{Message, VarMsg};


// We create some utility functions to make Empty and Full bodies
// fit our broadened Response body type.
fn empty() -> BoxBody<Bytes, hyper::Error> {
    Empty::<Bytes>::new()
        .map_err(|never| match never {})
        .boxed()
}
fn full<T: Into<Bytes>>(chunk: T) -> BoxBody<Bytes, hyper::Error> {
    Full::new(chunk.into())
        .map_err(|never| match never {})
        .boxed()
}


#[derive(Debug, Clone)]
pub struct Svc {
    tx_cfg: sync::broadcast::Sender<Message>,
}

fn mk_response(status: StatusCode, s: String) -> Result<Response<BoxBody<Bytes, hyper::Error>>, hyper::Error> {
    Ok(Response::builder()
        .status(status)
        .body(full(s))
        .unwrap())
}

fn mk_status(status: StatusCode) -> Result<Response<BoxBody<Bytes, hyper::Error>>, hyper::Error> {
    Ok(Response::builder()
        .status(status)
        .body(empty())
        .unwrap())
}

impl Svc {
    // Note that these are not methods that consume &self since that introduces
    // lifetime issues for the future (?).
    async fn set_config(req: Request<Incoming>, tx_cfg: sync::broadcast::Sender<Message>) -> Result<Response<BoxBody<Bytes, hyper::Error>>, hyper::Error> {
        let bytes = req.into_body().collect().await.unwrap().to_bytes();
        let json_str = String::from_utf8(bytes.into_iter().collect()).expect("");

        match json::parse(&json_str) {
            Ok(json_val) => match json_val {
                JsonValue::Object(json_obj) => match tx_cfg.send(Message::Config(json_obj)) {
                    Ok(_) => mk_status(StatusCode::OK),
                    Err(why) => {
                        print!("Failed to send config: {why}\n");
                        mk_status(StatusCode::INTERNAL_SERVER_ERROR)
                    }
                },
                _ => {
                    println!("JSON is not an object");
                    mk_status(StatusCode::BAD_REQUEST)
                }
            },
            Err(why) => {
                print!("JSON parse failure: {why}\n");
                mk_status(StatusCode::BAD_REQUEST)
            }
        }
    }

    async fn set_scalar(req: Request<Incoming>, tx_cfg: sync::broadcast::Sender<Message>) -> Result<Response<BoxBody<Bytes, hyper::Error>>, hyper::Error> {
        let bytes = req.into_body().collect().await.unwrap().to_bytes();
        let json_str = String::from_utf8(bytes.into_iter().collect()).expect("");
        
        match json::parse(&json_str) {
            Ok(data) => match data {
                JsonValue::Object(data) => {
                    // TODO: this error handling is lazy
                    let index = data.get("index").unwrap().as_usize().unwrap();
                    let value = data.get("value").unwrap().as_f32().unwrap();

                    match tx_cfg.send(Message::SetScalar(VarMsg::<f32> { index, value })) {
                        Ok(_) => mk_status(StatusCode::OK),
                        Err(why) => {
                            print!("Failed to send scalar: {why}\n");
                            mk_status(StatusCode::INTERNAL_SERVER_ERROR)
                        }
                    }
                }
                _ => {
                    println!("JSON is not an object");
                    mk_status(StatusCode::BAD_REQUEST)
                }
            },
            Err(why) => {
                print!("JSON parse failure: {why}\n");
                mk_status(StatusCode::BAD_REQUEST)
            }
        }
    }

    async fn set_data(req: Request<Incoming>, tx_cfg: sync::broadcast::Sender<Message>) -> Result<Response<BoxBody<Bytes, hyper::Error>>, hyper::Error> {
        let bytes = req.into_body().collect().await.unwrap().to_bytes();
        let json_str = String::from_utf8(bytes.into_iter().collect()).expect("");
        
        match json::parse(&json_str) {
            Ok(data) => match data {
                JsonValue::Object(data) => {
                    // TODO: this error handling is lazy
                    let index = data.get("index").unwrap().as_usize().unwrap();
                    let b64_str = data.get("value").unwrap().as_str().unwrap();
                    let value = BASE64_STANDARD.decode(b64_str).unwrap();

                    match tx_cfg.send(Message::SetData(VarMsg::<Vec<u8>> { index, value })) {
                        Ok(_) => mk_status(StatusCode::OK),
                        Err(why) => {
                            print!("Failed to send scalar: {why}\n");
                            mk_status(StatusCode::INTERNAL_SERVER_ERROR)
                        }
                    }
                }
                _ => {
                    println!("JSON is not an object");
                    mk_status(StatusCode::BAD_REQUEST)
                }
            },
            Err(why) => {
                print!("JSON parse failure: {why}\n");
                mk_status(StatusCode::BAD_REQUEST)
            }
        }
    }
}

impl Service<Request<Incoming>> for Svc {
    type Response = Response<BoxBody<Bytes, hyper::Error>>;
    type Error = hyper::Error;
    type Future = Pin<Box<dyn Future<Output = Result<Self::Response, Self::Error>> + Send>>;

    fn call(&self, req: Request<Incoming>) -> Self::Future {
        match (req.method(), req.uri().path()) {
            // This was really hard to get compiling. I still don't know if it's right.
            // Between opaque types (impl Future) not matching between match branches
            // and lifetimes issues of &self, this took nearly all day.
            // TODO: look at BoxFuture and explicitly define the lifetime of the future
            // as the lifetime of the server (or the lifetime of tx_cfg?)
            (&Method::POST, "/set_config") => {
                return Box::pin(Self::set_config(req, self.tx_cfg.clone()))
            }
            (&Method::POST, "/set_scalar") => {
                return Box::pin(Self::set_scalar(req, self.tx_cfg.clone()))
            }
            (&Method::POST, "/set_data") => {
                return Box::pin(Self::set_data(req, self.tx_cfg.clone()))
            }
            _ => {
                return Box::pin(async {mk_status(StatusCode::NOT_FOUND)})
            }
        };
    }
}

pub async fn server_run(tx_cfg: sync::broadcast::Sender<Message>) {
    /* HTTP Server initialization */

    // We'll bind to 127.0.0.1:3000
    let addr = SocketAddr::from(([0, 0, 0, 0], 3000));
    let listener = TcpListener::bind(addr).await.unwrap();
    
    print!("Server listening on {addr}\n");
    
    // We start a loop to continuously accept incoming connections
    loop {
        let (stream, _) = listener.accept().await.unwrap();
        
        // Use an adapter to access something implementing `tokio::io` traits as if they implement
        // `hyper::rt` IO traits.
        let io = TokioIo::new(stream);
        let lcl_tx_cfg = tx_cfg.clone();
        
        // Spawn a tokio task to serve multiple connections concurrently
        tokio::task::spawn(async move {
            // Finally, we bind the incoming connection to our `hello` service
            let svc = Svc {tx_cfg: lcl_tx_cfg};
            if let Err(err) = auto::Builder::new(TokioExecutor::new())
                .serve_connection(io, svc)
                .await
            {
                println!("Error serving connection: {:?}", err);
            }
        });
    }    
}
