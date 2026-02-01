use actix_web::{web, App, HttpResponse, HttpServer, Responder, post, get};
use actix_cors::Cors;
use actix_files as fs;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::{SystemTime, UNIX_EPOCH};

const VALID_TOKEN: &str = "你的key";

#[derive(Clone, Debug)]
struct DeviceInfo {
    status: String,
    exe: String,
    last_update: u64,
}

type DeviceMap = Arc<Mutex<HashMap<String, DeviceInfo>>>;

#[derive(Deserialize)]
struct UploadRequest {
    token: String,
    device_id: String,
    status: String,
    exe: String,
}

#[derive(Serialize)]
struct SuccessResponse {
    success: bool,
    message: String,
}

#[derive(Serialize)]
struct ErrorResponse {
    success: bool,
    error: String,
}

#[derive(Serialize)]
struct DeviceStatusResponse {
    success: bool,
    device_id: String,
    status: String,
    exe: String,
}

fn get_current_timestamp() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs()
}

#[post("/api/upload")]
async fn upload_device_status(
    req: web::Json<UploadRequest>,
    device_map: web::Data<DeviceMap>
) -> impl Responder {
    if req.token != VALID_TOKEN {
        return HttpResponse::Unauthorized().json(ErrorResponse {
            success: false,
            error: "Invalid token".to_string(),
        });
    }

    let mut devices = device_map.lock().unwrap();
    devices.insert(
        req.device_id.clone(),
        DeviceInfo {
            status: req.status.clone(),
            exe: req.exe.clone(),
            last_update: get_current_timestamp(),
        },
    );

    println!(
        "Device updated: {} - status: {}, exe: {}",
        req.device_id, req.status, req.exe
    );

    HttpResponse::Ok().json(SuccessResponse {
        success: true,
        message: format!("Device {} status updated", req.device_id),
    })
}

#[get("/api/status/{device_id}")]
async fn get_device_status(
    device_id: web::Path<String>,
    device_map: web::Data<DeviceMap>
) -> impl Responder {
    let devices = device_map.lock().unwrap();
      match devices.get(device_id.as_str()) {
        Some(device_info) => {
            let current_time = get_current_timestamp();
            let time_diff = current_time - device_info.last_update;
            
            // 如果上传的状态是 dead,直接返回 dead
            // 否则检查是否超过5分钟未更新
            let status = if device_info.status == "dead" {
                "dead".to_string()
            } else if time_diff > 300 {
                "dead".to_string()
            } else {
                device_info.status.clone()
            };
            
            HttpResponse::Ok().json(DeviceStatusResponse {
                success: true,
                device_id: device_id.to_string(),
                status,
                exe: device_info.exe.clone(),
            })
        }
        None => {
            HttpResponse::NotFound().json(ErrorResponse {
                success: false,
                error: format!("Device {} not found", device_id),
            })
        }
    }
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {    let device_map: DeviceMap = Arc::new(Mutex::new(HashMap::new()));

    println!("🚀 Server starting at http://127.0.0.1:8080");
    println!("📡 POST /api/upload - Upload device status");
    println!("📡 GET  /api/status/{{device_id}} - Get device status");

    HttpServer::new(move || {
        let cors = Cors::default()
            .allow_any_origin()
            .allow_any_method()
            .allow_any_header()
            .max_age(3600);

        App::new()
            .wrap(cors)
            .app_data(web::Data::new(device_map.clone()))
            .service(upload_device_status)
            .service(get_device_status)
    })
    .bind(("127.0.0.1", 8080))?
    .run()
    .await
}
