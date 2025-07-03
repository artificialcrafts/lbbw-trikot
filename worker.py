import os
import subprocess
import time
import json
import boto3
import sys
import shutil
import urllib.parse
from pathlib import Path
from comfyui import ComfyUI

# --- Configuration ---
QUEUE_URL = os.environ.get("SQS_QUEUE_URL", "https://sqs.eu-central-1.amazonaws.com/320819923469/lbbw-trikot-queue")
AWS_REGION = os.environ.get("AWS_REGION", "eu-central-1")
OUTPUT_DIR = "/tmp/outputs"
INPUT_DIR = "/tmp/inputs"

def download_file(url, destination_path):
    """
    Downloads a file from either an S3 URI or an HTTPS URL.
    """
    print(f"Preparing to download from: {url}")
    if url.startswith('s3://'):
        # Use AWS CLI for S3 URIs
        command = ["aws", "s3", "cp", url, destination_path, "--only-show-errors"]
        print("Downloading with AWS CLI...")
    elif url.startswith(('http://', 'https://')):
        # Use curl for HTTP/HTTPS URLs
        command = ["curl", "-L", "-o", destination_path, url]
        print("Downloading with curl...")
    else:
        raise ValueError(f"Unsupported URL scheme for: {url}")

    try:
        subprocess.run(command, check=True)
        print(f"Successfully downloaded to {destination_path}")
    except subprocess.CalledProcessError as e:
        print(f"ERROR: Download failed for {url}. Error: {e}")
        raise

def upload_file_to_s3(local_path, s3_url):
    """Uploads a file to S3 using the AWS CLI."""
    try:
        print(f"Uploading {local_path} to {s3_url}...")
        command = ["aws", "s3", "cp", local_path, s3_url, "--only-show-errors"]
        subprocess.run(command, check=True)
        print("Upload successful.")
    except subprocess.CalledProcessError as e:
        print(f"ERROR: S3 upload failed: {e}")
        raise

def process_message(message, comfy_client, prepare_only=True):
    """Processes a single job message from the SQS queue."""
    print(f"--- New Job Received (MessageID: {message.get('MessageId', 'NO-ID')}) ---")
    try:
        job_data = json.loads(message['Body'])
        workflow_data = job_data['workflow']
        
        comfy_client.cleanup([OUTPUT_DIR, INPUT_DIR, "ComfyUI/temp"])

        # --- Prepare Inputs and Dynamically Update Workflow ---
        if 'inputs' in job_data:
            for local_filename, uri in job_data['inputs'].items():
                local_dest_path = os.path.join(INPUT_DIR, local_filename)
                download_file(uri, local_dest_path)
                
                # Find any LoadImage node that expects this filename and confirm
                for node in workflow_data.values():
                    if node.get("class_type") == "LoadImage" and node["inputs"].get("image") == local_filename:
                        print(f"Confirmed workflow node will use downloaded file: {local_filename}")
        
        # --- Run Workflow or Prepare Only ---
        wf = comfy_client.load_workflow(workflow_data)
        comfy_client.connect()

        if prepare_only:
            print("[WARMUP] Preparation done, skipping actual workflow execution.")
            return True  # or False, as you prefer

        comfy_client.run_workflow(wf)
        
        output_files = comfy_client.get_files([OUTPUT_DIR, "ComfyUI/temp"])
        if not output_files:
            raise RuntimeError("Workflow did not generate any output files.")
        
        generated_file = output_files[0]
        s3_url = job_data['s3_url']
        upload_file_to_s3(str(generated_file), s3_url)

    except Exception as e:
        print(f"ERROR processing job: {e}")
        return False

    return True

def main():
    if not QUEUE_URL:
        print("FATAL: SQS_QUEUE_URL is not configured. Exiting.")
        sys.exit(1)

    comfyUI = ComfyUI("127.0.0.1:8188")
    server_process = comfyUI.start_server(OUTPUT_DIR, INPUT_DIR)

    # --- WARM-UP JOB HANDLING ---
    warmup_job_path = os.environ.get("WARMUP_JOB_PATH")
    if len(sys.argv) > 1:
        warmup_job_path = sys.argv[1]

    if warmup_job_path and warmup_job_path.startswith("s3://"):
        local_warmup_job_path = "/tmp/warmup_job.json"
        print(f"[Warmup] Downloading S3 warmup job {warmup_job_path} to {local_warmup_job_path}")
        subprocess.run(["aws", "s3", "cp", warmup_job_path, local_warmup_job_path], check=True)
        warmup_job_path = local_warmup_job_path

    if warmup_job_path and os.path.exists(warmup_job_path):
        print(f"\n[Warmup] Processing warmup job at {warmup_job_path}")
        with open(warmup_job_path) as f:
            warmup_job = json.load(f)
        fake_message = {"MessageId": "warmup-1", "Body": json.dumps(warmup_job)}
        process_message(fake_message, comfyUI, prepare_only=True)
        print("[Warmup] Done.\n")

    sqs = boto3.client('sqs', region_name=AWS_REGION)
    print(f"Worker started successfully. Polling SQS queue: {QUEUE_URL}")
    
    while True:
        try:
            response = sqs.receive_message(
                QueueUrl=QUEUE_URL,
                MaxNumberOfMessages=1,
                WaitTimeSeconds=20
            )

            if "Messages" in response:
                message = response["Messages"][0]
                receipt_handle = message['ReceiptHandle']
                
                if process_message(message, comfyUI):
                    sqs.delete_message(
                        QueueUrl=QUEUE_URL,
                        ReceiptHandle=receipt_handle
                    )
                    print("Job complete. Message deleted. Polling for next job...")
            else:
                print(".", end="", flush=True)

        except KeyboardInterrupt:
            print("\nShutdown signal received. Exiting worker loop.")
            break
        except Exception as e:
            print(f"\nAn unexpected error occurred in the main loop: {e}")
            time.sleep(10)
    
    print("Shutting down ComfyUI server...")
    server_process.terminate()
    server_process.wait()
    print("Worker stopped.")

if __name__ == "__main__":
    main()
