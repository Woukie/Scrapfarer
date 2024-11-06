-- Central limit based estimate of normal distribution for RNG
function RandomNormal(mean, range, accuracy)
  if not accuracy then
    accuracy = 10
  end

  local sum = 0.0
  for i = 1, accuracy * 2, 1 do
    sum = sum + math.random()
  end

  return range * (sum / accuracy - 1) + mean
end
