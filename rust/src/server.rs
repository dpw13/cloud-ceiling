use hyper::{Body, Request, Response, Server, Method, StatusCode};
use hyper::service::{make_service_fn, service_fn};
use tokio::sync;
use json::JsonValue;
use std::convert::Infallible;
use std::net::SocketAddr;

async fn endpoint_impl(req: Request<Body>, tx_cfg: sync::broadcast::Sender<json::object::Object>) -> Result<Response<Body>, Infallible> {
    let mut response = Response::new(Body::empty());
    let method = Method::to_owned(req.method());
    let uri = req.uri().clone();

    match (&method, uri.path()) {
        (&Method::POST, "/set_config") => {
            let bytes = hyper::body::to_bytes(req.into_body()).await.unwrap();
            let json_str = String::from_utf8(bytes.into_iter().collect()).expect("");

            *response.status_mut() = match json::parse(&json_str) {
                Ok(json_val) => match json_val {
                    JsonValue::Object(json_obj) => match tx_cfg.send(json_obj) {
                        Ok(_) => StatusCode::OK,
                        Err(why) => {
                            print!("Failed to send config: {why}\n");
                            StatusCode::INTERNAL_SERVER_ERROR
                        },
                    }
                    _ => {
                        println!("JSON is not an object");
                        StatusCode::BAD_REQUEST
                    },
                },
                Err(why) => {
                    print!("JSON parse failure: {why}\n");
                    StatusCode::BAD_REQUEST
                },
            };
        },
        _ => {
            *response.status_mut() = StatusCode::NOT_FOUND;
        },
    }

    println!("{} {} -> {}", method, uri.path(), response.status());
    Ok(response)
}

pub async fn server_setup(tx_cfg: sync::broadcast::Sender<json::object::Object>) {
    /* HTTP Server initialization */

    // We'll bind to 127.0.0.1:3000
    let addr = SocketAddr::from(([0, 0, 0, 0], 3000));

    // A `Service` is needed for every connection, so this
    // creates one from our `endpoint_impl` function.
    let make_svc = make_service_fn(move |conn: &hyper::server::conn::AddrStream| {
        // Clone the broadcast sender before we create the service function itself.
        let tx_cfg = tx_cfg.clone();
        let remote = conn.remote_addr();
        print!("Got connection from {remote}\n");

        // This is the actual service function, which will reference a cloned tx_cfg.
        async move {
            // service_fn converts our function into a `Service`
            Ok::<_, Infallible>(service_fn(move |req| { endpoint_impl(req, tx_cfg.clone()) }))
        }
    });

    let server = Server::bind(&addr).serve(make_svc);

    print!("Server listening on {addr}\n");

    if let Err(e) = server.await {
        panic!("Server error: {}", e);
    }

    print!("Server terminated, should never get here");
}
