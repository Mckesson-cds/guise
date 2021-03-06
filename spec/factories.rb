FactoryGirl.define do

  factory :user do
    name 'Micro Helpline'
    email 'mrhalp@mit.edu'

    factory :technician do
      after(:create) do |user, proxy|
        create(:user_role, name: 'Technician', user: user)
      end
    end

    factory :supervisor do
      after(:create) do |user, proxy|
        create(:user_role, name: 'Supervisor', user: user)
      end
    end
  end

  factory :person do
  end

  factory :permission do
    person
    privilege 'Admin'
  end

  factory :user_role do
    user
    name 'Technician'

    factory :technician_role do
    end

    factory :supervisor_role do
      name 'Supervisor'
    end
  end
end
