package main

deny contains msg if {
  some service_name
  service := input.services[service_name]
  image := object.get(service, "image", "")
  endswith(image, ":latest")
  msg := sprintf("El servicio %s usa imagen latest: %s", [service_name, image])
}

deny contains msg if {
  some service_name
  service := input.services[service_name]
  object.get(service, "privileged", false) == true
  msg := sprintf("El servicio %s no debe ejecutarse en modo privileged", [service_name])
}

deny contains msg if {
  some service_name
  service := input.services[service_name]
  env := object.get(service, "environment", [])
  is_array(env)
  some i
  item := env[i]
  contains(lower(item), "password=")
  msg := sprintf("El servicio %s contiene password hardcodeado: %s", [service_name, item])
}

deny contains msg if {
  some service_name
  service := input.services[service_name]
  env := object.get(service, "environment", {})
  is_object(env)
  some key
  env[key]
  contains(lower(key), "password")
  msg := sprintf("El servicio %s contiene password hardcodeado en variable: %s", [service_name, key])
}
