let
  ramona = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKK5e1b1wQLyZ0RByYmhlKj4Kksv4dvnwTowDPaGsq4D openpgp:0x7688871E";

  users = [ ramona ];

  ananas = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKK5e1b1wQLyZ0RByYmhlKj4Kksv4dvnwTowDPaGsq4D openpgp:0x7688871E";
  shadowmend = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDiWY5wJeGVrXM88JQtolgjMKDstficIf+feng/XQP7kVoAMbmGbq7+Qa1bkaP/ov0ib+GDtN0hhmn/GIo55BMGmuAXTooMp372hMX8VJRucmn4APrga5NBDhHCvc1V1icHShLtKvpXr5M/Yr6/MHsGrqLGhCdVkpiB3Zrtmc4bTVbmdg+pDfZUgrY8p/uSic/nKQEBGUsvOuqc6KZnHcIyoBRZjpe50R3w8mlCKXribTzDR4/JArYCZThwzZsUl6aTC5FyGFjcazQCjg8NS75wPbHUu4kXpnMVp0eepLrrJCS+QFV3psk4jvhjuhKu3ciVLqWYXZ2CHqkHsBTGQFm3EFlHY7LknsTsHKzJvbyyOMMTdiE88YqTGHTuui3iPFrCYNCGQAJIOSdWOjAKmv490E4/CjOnUQKsly9JMgk5Exaoz3Xcz6LGkvnJVarSI1ozD5iUvtQ/yLZC9QVK03HQBuLEO3aO1BLY9bJuaGskY8cDQTU0LUoELFTFcAJvoKHF/SZtyQbiAVH2WKx269bS+oXUYCVdn5o7uSIuFXh1VgVmejlXtZqZcTjDAOrxgEyN9YCav6YpN/MWgvPtl7rEY/JoSOLLPDxOyqUI2ngH2UrFEwBYUVHtBWlFD4N/uumz/t56XrF5d6GSu0+8FWko1kRCjcdUnZoQ1yFqdmwH5w==";
  hallewell = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCuqrAiE9QR6zvndMLUHNdEwr5x9EZ1OZKU5QEcT8G9iwK9WE3oLzgXS3eL3uDs0GrKmt1GA8PBj9rpkXsxU3d4vUYBLNM6UTIMsMAPvuBnBiKi3qhngcpSIne5E/ZAzAj1H3WWJ1XBCaP4pX67xe1ncBK7L/sju5o04nJoqqjEtXnE3NJx3SW4ZJurn6gP13HHkdcz/Rk2qxj77vemIU9xSXSqETGZet6rh5B29fOaJG4DejaYHnhTzZmq6wV9f8YzkUhuNl903HdwtqYtnnLxBgUvD6+1A2/Dc9Zf1jdwK1wCsC6XVo7Ez2dnP7lZvM/Wdw1Lf7RETDYsMJLLIwxKB+ZjEaz5YYDA3St2Qa6JyfzUZ309nW2PKAzATJHTi6QVuITsRoR5JDLN+u8KgiUmjyUP4CRsYU9GOohDi99UZuh9Kf7xkHQ3RvhBHaWWvz0zItnZzKw/U+FSxm9gWScuU7HvnZprROh+sCh9vbvG2SAj+YNTLPl5pZGE9deBu5npzwaYv8u5HMI5uaOdp+1JnBLWoSIY2U9at0f4g5vn/Hgxu9C1odH7AkmHNaBlyjRNnQF9ln7TL0A5FpjhCBbP8lcVSlywkuApc7yj9RFr+BEDsBBASXtDXYh7hN2hbHgFFbr5fG5q98V8WJgiille0DX0zHNjdlJfRjK2O/nNsQ==";
  moonfall = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCqtuSskPiTaajnpvhLIeZUw6CB+ieHjCfwfRuGJ2Ax4qOj6CBw/1JGNnlr36pSkofsc5EFpzv6SQARTlt2OlISnPyQWvLnpCY9SgMVMHJmYZWocl9vAV1PM2h1SrQAcFK5KD8nZX7mpu9Nq5wMFPFCyFuBC/goh9WdXkOUJ+PTBu0eUYz+abKS1KEi3jsquda6rErcjsYe8WAIminobZf6SVDcgJACA3Fa7GKXhqVHIVJRUEDAYcir2P1kRBozGZrM4/HaCMwovU8B1jhzbOGETUGAwi95NXoIK1B9vbxm+XSSIOebVhJdZ1Y3GMcvtbwIUL1fC+r6E4W5pLY+TfOA1/r646M7LF51VUzsgZuzno57YkGQvp0ZVUqa0sWeMQHVaTSTfqH2R/PAW5jfUL/qwVnTQNQOihRSB0ns/JCS+zTkQx1I0149cRcfUmghVq3aI5HALWn79JaJ/zH1JGVBrk130NErRMlSLBxEQg7eOzi9AR4MwPswB0S0L7oFbIjF4Q8bPxUS9LvUeRJ32dBPGEYYGWqkYUW2o/Rz2BOuqjVOqsVxq11971rbSVcfw4nR24uNQGcTqjgafROvQPKWPq4jtlr3QeJP46Uw9rno3NNevmqf8JrTSlkPYIEW5aFDie3D/dgWd/QjA1A6Upmo4z3b68ibrszkL4JcrANqWw==";
  angelsin = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDD5aFk1GzydeSz09RrokKhqmtDpQLi4fw5T4UQ1sLiqjOqgK9Z0gwW4+97GMAmZtZWmQsIxZjunrvjypXFYD/HngF/PcGCtxVqMOb25qtJvE3jnOkMEjiVEg8uHCUIiALymn8ALay6el0MpRtCYNnPuJFdDjeLsSsKuiavn0i7GDj8jxgJ4lGpQf8043ZHVqENtip7trxDnTD/K81Oyb3hOv/LXqq550Q5r5zZCKVSSjyU9hQklGaCNNczCKZCiPI4gEmHx+TScC+Habmbw8CZCYy/rlrzW4QYZC49zrg26/A9bx9xNlYSGGS9MQUDpNcVA1fj+0WCsongryScNIn5Nb+reN8EiOyObSkR3vQXIlf2EmLdQghqiEwh2G6PVamDUEbeByCvHmrVrZ34Kgm9jyQYey62J3cJec0yD6MTBBujCwvigWiSI9VlV/Ty+hzOPrKhadpK4Wg+qyaa2rDUCEXeZKYL2JO9wsOzHCRv4DIdBmPm0rr3oKpebDxuOVhtpQrdqSJYKLvFAIvA57oRH2/Tlt78jVI3wjADJpR92rLL680OaA51HzkRYJciVjKOyi2rfW34dZQ6zVa16d2g6nI9UM9jM3SLof/iR1/35l6loDUoaV/7H1vFjRldCbFnsY7YlKDD9lLYIAqtFYTSnhMVYx67kmbpWLgyn578WQ==";
in 
{
  "rabbitmq-ha.age".publicKeys = users ++ [shadowmend];
  "minio-root.age".publicKeys = users ++ [hallewell];
  "minio-tempo.age".publicKeys = users ++ [hallewell];
}
