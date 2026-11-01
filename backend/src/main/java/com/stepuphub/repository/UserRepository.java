package com.stepuphub.repository;

import com.stepuphub.domain.Role;
import com.stepuphub.domain.User;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByEmail(String email);
    boolean existsByEmail(String email);
    List<User> findByRole(Role role);
    List<User> findByRoleAndApproved(Role role, boolean approved);
    List<User> findByRoleAndApprovedAndActive(Role role, boolean approved, boolean active);
}
