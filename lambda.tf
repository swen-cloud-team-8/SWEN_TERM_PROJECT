locals{
# instead of referring to same value twice, it is better to declare it as a local variable. Access local variables with syntax -> local.variableName
  lambda_zip_location = "sns-lambda.zip"
  emails = ["ameyshahane1012@gmail.com"]
}

 data "archive_file" "sns-lambda" {
   type        = "zip"
   source_file = "sns-lambda.py"
   #Tell a data archive file to create a zip of the script and store it in the output location. Load output into the lamnda function
   output_path = "${local.lambda_zip_location}"
}

 resource "aws_lambda_function" "crowd_lambda" {
   #will need to update twice in case of any change, better to introduce local variables
   filename      = "${local.lambda_zip_location}"
   function_name = "sns-s3-lambda"
   role          = "${aws_iam_role.lambda_role.arn}"
   #Format is filename.method name -> welcome.hello. When lambda() is triggerd, it loads the welcome.py script and in that it calls hello()
   handler       = "sns-lambda.lambda_handler"
   source_code_hash = "${filebase64sha256(local.lambda_zip_location)}"
   runtime = "python3.7"
}

#To ensure redploy if we make changes to lambda function source code, uncomment source_code_hash. When source file containing py script for lambda changes, the hashcode of the source file will change which will cause terraform to redeploy 
#source_code_hash = filebase64sha256("lambda_function_payload.zip")
# No environment variables
