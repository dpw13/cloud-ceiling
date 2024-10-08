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
use std::sync::Arc;
use tokio::{
    sync::broadcast::Sender,
    sync::broadcast::error::*,
    net::TcpListener,
};
use hyper_util::{
    rt::TokioExecutor,
    rt::TokioIo,
    server::conn::auto,
};

use crate::modular_msg::{ModularMessage, Settable};
use crate::led_msg::LedMessage;
use crate::var_types::*;

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
    led_cmd: Arc<Sender<LedMessage>>,
    mod_cmd: Arc<Sender<ModularMessage>>,
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

    /* Handles parsing the top-level JSON into an Object */
    async fn set_generic<F>(req: Request<Incoming>, func: F) -> Result<Response<BoxBody<Bytes, hyper::Error>>, hyper::Error>
        where F: FnOnce(json::object::Object) -> Result<Response<BoxBody<Bytes, hyper::Error>>, hyper::Error>
        {
        let bytes = req.into_body().collect().await.unwrap().to_bytes();
        let json_str = String::from_utf8(bytes.into_iter().collect()).expect("");

        match json::parse(&json_str) {
            Ok(data) => match data {
                JsonValue::Object(data) => {
                    func(data)
                }
                _ => {
                    println!("JSON is not an object");
                    mk_status(StatusCode::BAD_REQUEST)
                }
            },
            Err(why) => {
                println!("JSON parse failure: {why}");
                mk_status(StatusCode::BAD_REQUEST)
            }
        }
    }

    /* Parses the full config and passes it to the render block */
    async fn set_config(req: Request<Incoming>, mod_cmd: Arc<Sender<ModularMessage>>) -> Result<Response<BoxBody<Bytes, hyper::Error>>, hyper::Error> {
        Self::set_generic(req, |json_obj| {
            match mod_cmd.send(ModularMessage::Config(json_obj)) {
                Ok(_) => mk_status(StatusCode::OK),
                Err(why) => {
                    println!("Failed to send config: {why}");
                    mk_status(StatusCode::INTERNAL_SERVER_ERROR)
                }
            }
        }).await
    }

    /* Parses the index and value for setting a value */
    async fn set_value<F, T>(req: Request<Incoming>, func: F) -> Result<Response<BoxBody<Bytes, hyper::Error>>, hyper::Error>
        where F: FnOnce(usize, &JsonValue) -> Result<usize, SendError<T>> {
        Self::set_generic(req, |data| {
            let index = data
                .get("index").expect("Missing index parameter")
                .as_usize().expect("Index parameter must be an integer");
            let obj = data
                .get("value").expect("Missing value parameter");

            match func(index, obj) {
                Ok(_) => {
                    mk_status(StatusCode::OK)
                },
                Err(why) => {
                    println!("Failed to send scalar: {why}");
                    mk_status(StatusCode::INTERNAL_SERVER_ERROR)
                }
            }
        }).await
    }

    /* Uses the FromJson trait to parse the value and the Settable trait to generate
     * the proper message variant, then sends it. */
    async fn set_object<T: FromJson + Settable>(req: Request<Incoming>, mod_cmd: Arc<Sender<ModularMessage>>) -> Result<Response<BoxBody<Bytes, hyper::Error>>, hyper::Error> {
        Self::set_value(req, |index, obj| {
            let value = T::from_obj(obj);
            //println!("Set {} idx {index}", std::any::type_name::<T>());
            mod_cmd.send(T::into_message(index, value))
        }).await
    }

    async fn set_white_led(req: Request<Incoming>, led_cmd: Arc<Sender<LedMessage>>) -> Result<Response<BoxBody<Bytes, hyper::Error>>, hyper::Error> {
        let bytes = req.into_body().collect().await.unwrap().to_bytes();
        let json_str = String::from_utf8(bytes.into_iter().collect()).expect("");

        match json::parse(&json_str) {
            Ok(data) => match data {
                JsonValue::Object(data) => {
                    let temp = data
                        .get("temp").unwrap_or(&JsonValue::from(2700.0))
                        .as_f32().expect("Temp parameter must be a float");
                    let value = data
                        .get("value").unwrap_or(&JsonValue::from(1.0))
                        .as_f32().expect("Value parameter must be a float");
                    let delay = data
                        .get("delay").unwrap_or(&JsonValue::from(0.0))
                        .as_f32().expect("Delay parameter must be a float");
                    match led_cmd.send(LedMessage::SetWhiteTemp(temp, value, delay)) {
                        Ok(_) => {
                            mk_status(StatusCode::OK)
                        },
                        Err(why) => {
                            println!("Failed to send LED command: {why}");
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
                println!("JSON parse failure: {why}");
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
        //println!("{} to {}", req.method(), req.uri().path());
        match (req.method(), req.uri().path()) {
            // This was really hard to get compiling. I still don't know if it's right.
            // Between opaque types (impl Future) not matching between match branches
            // and lifetimes issues of &self, this took nearly all day.
            // TODO: look at BoxFuture and explicitly define the lifetime of the future
            // as the lifetime of the server (or the lifetime of mod_cmd?)
            (&Method::POST, "/set_config") => {
                return Box::pin(Self::set_config(req, self.mod_cmd.clone()))
            }
            (&Method::POST, "/set_scalar") => {
                return Box::pin(Self::set_object::<f32>(req, self.mod_cmd.clone()))
            }
            (&Method::POST, "/set_position") => {
                return Box::pin(Self::set_object::<Position>(req, self.mod_cmd.clone()))
            }
            (&Method::POST, "/set_color") => {
                return Box::pin(Self::set_object::<Color>(req, self.mod_cmd.clone()))
            }
            (&Method::POST, "/set_rcolor") => {
                return Box::pin(Self::set_object::<RealColor>(req, self.mod_cmd.clone()))
            }
            (&Method::POST, "/set_data") => {
                return Box::pin(Self::set_object::<Data>(req, self.mod_cmd.clone()))
            }
            (&Method::POST, "/set_white_led") => {
                return Box::pin(Self::set_white_led(req, self.led_cmd.clone()))
            }
            _ => {
                return Box::pin(async {mk_status(StatusCode::NOT_FOUND)})
            }
        };
    }
}

pub async fn server_run(mod_cmd: Sender<ModularMessage>, led_cmd: Sender<LedMessage>) {
    /* HTTP Server initialization */

    // We'll bind to 127.0.0.1:3000
    let addr = SocketAddr::from(([0, 0, 0, 0], 3000));
    let listener = TcpListener::bind(addr).await.unwrap();

    println!("Server listening on {addr}");
    let svc = Svc {
        led_cmd: Arc::new(led_cmd),
        mod_cmd: Arc::new(mod_cmd)};

    // We start a loop to continuously accept incoming connections
    loop {
        let (stream, _) = listener.accept().await.unwrap();
        
        println!("Connection from {}", stream.peer_addr().unwrap());

        // Use an adapter to access something implementing `tokio::io` traits as if they implement
        // `hyper::rt` IO traits.
        let io = TokioIo::new(stream);
        let svc_clone = svc.clone();

        // Spawn a tokio task to serve multiple connections concurrently
        tokio::task::spawn(async move {
            // Finally, we bind the incoming connection to our `hello` service
            if let Err(err) = auto::Builder::new(TokioExecutor::new())
                .serve_connection(io, svc_clone)
                .await
            {
                println!("Error serving connection: {:?}", err);
            }
        });
    }
}
